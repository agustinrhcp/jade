require 'jade/decode'
require 'jade/result'
require 'jade/interop/error'

module Jade
  module Interop
    module Boundary
      extend self

    # Boundary-side decode: succeed → return the value, fail → raise. The
    # Result wrap/unwrap that user-level Decode.from_value uses is dead
    # weight at the boundary because failure always raises anyway. Skipping
    # it removes one allocation per arg per Ruby→Jade call.
      # Crossing the boundary costs 10x to 30x what the same call costs
      # inside Jade, so a loop that crosses per row is the usual reason a
      # project decides Jade is slow. Counting is off until asked:
      # `JADE_BOUNDARY_WARN=1000`, or `Boundary.watch`.
      WARN_AFTER = 1_000

      # A loop crosses a thousand times in a moment. A busy endpoint
      # crosses once per request all afternoon and is fine, so the count
      # that means anything is the one inside a short window.
      WINDOW = 1.0

      def watch_from_env
        ENV['JADE_BOUNDARY_WARN']&.then { watch(after: Integer(it, exception: false) || WARN_AFTER) }
      end

      def watch(after: WARN_AFTER, window: WINDOW)
        @after = after
        @window = window
        @counts = Hash.new(0)
        @batches = {}
        @warned = {}
      end

      def unwatch
        @counts = nil
        @batches = nil
        @warned = nil
      end

      def watching?
        !@counts.nil?
      end

      def stats
        (@counts || {}).sort_by { -it.last }.to_h
      end

      def crossing(name)
        return unless @counts

        count = @counts[name] += 1
        @batches[name] = clock if count == 1
        batch(name, count) if (count % @after).zero?
      end

      # Reading the clock on every crossing would cost more than the
      # crossing it is measuring, so read it once per batch of `after` and
      # ask how long the batch took.
      def batch(name, count)
        now = clock
        started = @batches[name]
        @batches[name] = now
        warn_once(name, count, now - started) if now - started <= @window
      end

      def clock
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end

      def warn_once(name, count, seconds)
        return if @warned[name]

        @warned[name] = true
        Kernel.warn(
          "[jade] #{name} crossed the Ruby boundary #{count} times in " \
            "#{format('%.1f', seconds)}s. A crossing decodes what you hand " \
            'it, so the cost follows the data rather than the call count: ' \
            'handing the same values across on every pass is what hurts. ' \
            'Lift anything unchanging out of the loop, or take a list and ' \
            'cross once.',
        )
      end

      # Names the argument a failure came from. Costs nothing until one
      # does: Ruby only pays for a rescue that fires.
      def arg(where)
        yield
      rescue DecodeError => e
        raise e.under(where)
      end
      alias at arg

      # Finding the element costs a second pass, which only a failure pays
      # for: the map stays a map.
      def elements(array, where = nil)
        array.map { yield(it) }
      rescue DecodeError => e
        raise e.under("#{where}[#{failing_index(array) { yield(it) }}]")
      end

      def failing_index(array)
        array.each_with_index do |element, index|
          yield(element)
        rescue DecodeError
          return index
        end
      end

      # An absent key reads as nil to the field decoder, which then blames
      # the type it wanted. The path says which key that was, so a struct
      # can check whether it was ever there.
      def missing_field(error, hash)
        key = error.where.to_s[/\A\.([^.\[]+)/, 1]
        return error if key.nil? || hash.key?(key)

        error.as(Jade::Decode::MissingField[key])
      end

      def decode_or_raise(decoder, value)
        Jade::Decode::Runner.run!(decoder, value) do |error|
          raise Jade::Interop::DecodeError.new(error, value)
        end
      end

      # Specialized fast-path validators. Emitted by codegen for known-shape
      # argument types in place of the generic `decode_or_raise` path —
      # avoids constructing a Decoder descriptor and walking the
      # interpreter for primitives.
      def integer(label, v, where = nil)
        ::Integer === v ? v : type_error!(label, v, where)
      end

      def string(label, v, where = nil)
        ::String === v ? v.dup : type_error!(label, v, where)
      end

      def bool(label, v, where = nil)
        v == true || v == false ? v : type_error!(label, v, where)
      end

      def float(label, v, where = nil)
        ::Numeric === v ? v.to_f : type_error!(label, v, where)
      end

      def list_of(klass, label, v, where = nil)
        v.is_a?(::Array) && v.all? { klass === _1 } ? v : type_error!(label, v, where)
      end

      # Validates that v is an Array but doesn't check element types — used
      # when the per-element decoder isn't a simple `is_a?` (e.g. nested
      # structs). The caller maps a decoder over the result.
      def array(label, v, where = nil)
        v.is_a?(::Array) ? v : type_error!(label, v, where)
      end

      def hash(label, v)
        case v
        when ::Hash then string_keyed!(label, v)
        when ::Data then v.to_h.transform_keys(&:to_s)
        else type_error!(label, v, nil)
        end
      end

      # Mixed keys are a real shape mismatch; the per-field errors say more
      # than a guess about intent would.
      def string_keyed!(label, v)
        return v if v.empty? || v.keys.any?(::String)

        v.keys.grep(::Symbol)
          .then { it.empty? ? v : raise(Jade::Interop::SymbolKeys.new(label, it)) }
      end

      def type_error!(label, v, where)
        raise Jade::Interop::DecodeError.new(
          Jade::Decode::WrongType[label, Jade::Decode.type_name(v)],
          v,
          where:,
        )
      end
    end
  end
end

Jade::Interop::Boundary.watch_from_env

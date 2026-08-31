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
      def blame(error, hash, label)
        key = error.where.to_s[/\A\.([^.\[]+)/, 1]
        return error if key.nil? || hash.key?(key)

        symbol_keys!(label, hash)
        error.as(Jade::Decode::MissingField[key])
      end

      # Mixed keys are a real shape mismatch; the per-field errors say more
      # than a guess about intent would.
      def symbol_keys!(label, hash)
        return if hash.empty? || hash.keys.any?(::String)

        hash.keys.grep(::Symbol).then { raise SymbolKeys.new(label, it) unless it.empty? }
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

      # Symbol keys are not checked here: every field would then be
      # missing, and the rescue around the fields catches that for free.
      def hash(label, v)
        case v
        when ::Hash then v
        when ::Data then v.to_h.transform_keys(&:to_s)
        else type_error!(label, v, nil)
        end
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

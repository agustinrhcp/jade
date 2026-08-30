module Jade
  module Interop
    class Error < StandardError; end

    class PortNotRegistered < Error
      def initialize(module_name, function_name)
        super(
          "Port `#{function_name}` on `#{module_name}` is not a Jade port. " \
            "Add `extend Jade::Port` to `#{module_name}` and declare it with " \
            "`task :#{function_name} do |t, ...| ... end`."
        )
      end
    end

    # Raised when a Ruby caller invokes a Jade function whose signature
    # has no public boundary — typically a polymorphic fn, a fn with
    # function-typed args, or a fn over a type whose Decodable/Encodable
    # can't be derived. The user's options are to add an explicit
    # `implements Decodable/Encodable`, restructure the signature with
    # decodable types, or accept that the fn is Jade-internal only.
    class NotExposed < Error
      def initialize(module_name:, function_name:, hint: nil)
        ["#{module_name}.#{function_name} is not exposed to Ruby.", hint]
          .compact
          .join(' ')
          .then { super(it) }
      end
    end

    # Raised by bang-suffixed Task wrappers when the underlying Task ran
    # to the Err arm. The encoded err value is available on `.error` for
    # structured handling — pattern-match on it for shape-specific
    # recovery, or just inspect for logging.
    class TaskError < Error
      attr_reader :error

      def initialize(error)
        @error = error
        super("Task returned an error: #{error.inspect}")
      end
    end

    # Caught where the whole hash is in scope; downstream each field just
    # reads nil and blames its own type.
    class SymbolKeys < Error
      def initialize(label, keys)
        super(
          "#{label} expects a Hash with string keys, got symbol keys " \
            "(#{keys.take(4).map(&:inspect).join(', ')}). " \
            "Values cross the boundary as wire data — " \
            "try #{keys.first.to_s.inspect} rather than #{keys.first.inspect}."
        )
      end
    end

    class DecodeError < Error
      attr_reader :decode_error, :value, :source, :where

      SUBJECTS = {
        argument: 'Ruby passed a value that failed to decode',
        port_return: 'Port returned a value that failed to decode',
      }.freeze

      # Ruby has no null.
      TYPE_NAMES = { 'null' => 'nil' }.freeze

      def initialize(decode_error, value, source: :argument, where: nil)
        @decode_error = decode_error
        @value = value
        @source = source
        @where = where
        super(format(decode_error, value))
      end

      def at(where)
        self.class.new(decode_error, value, source:, where:)
      end

      private

      def format(error, value)
        path, leaf = unwind(error)

        case leaf
        in Jade::Decode::WrongType[expected, got]
          "#{subject(path)}: expected #{expected}, got #{type_name(got)}#{seen(value)}"

        in Jade::Decode::MissingField[key]
          "#{subject(path)}: missing field `#{key}`#{seen(value)}"

        in Jade::Decode::Custom[msg]
          "#{subject(path)}: #{msg}#{seen(value)}"

        in Jade::Decode::Multiple[errors]
          errors
            .map { format(it, value) }
            .join("; ")
        end
      end

      # `Shop.price(item).cents` when the caller said where it was, and the
      # old sentence when it did not.
      def subject(path)
        return "#{SUBJECTS.fetch(@source)} at #{path.empty? ? 'value' : path.join}" unless @where

        "#{@where}#{path.join}"
      end

      def type_name(got)
        TYPE_NAMES.fetch(got.to_s, got)
      end

      def seen(value)
        value.nil? ? '' : " (#{value.inspect})"
      end

      def unwind(error, path = [])
        case error
        in Jade::Decode::AtField[key, inner] then unwind(inner, path + [".#{key}"])
        in Jade::Decode::AtIndex[idx, inner] then unwind(inner, path + ["[#{idx}]"])
        else [path, error]
        end
      end
    end
  end
end

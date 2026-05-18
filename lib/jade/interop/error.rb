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

    class DecodeError < Error
      attr_reader :decode_error, :value

      def initialize(decode_error, value)
        @decode_error = decode_error
        @value = value
        super(format(decode_error, value))
      end

      private

      def format(error, value)
        path, leaf = unwind(error)
        location = path.empty? ? "value" : path.join

        case leaf
        in Jade::Decode::WrongType[expected, got]
          "Port returned a value that failed to decode at #{location}: expected #{expected}, got #{got} (#{value.inspect})"

        in Jade::Decode::MissingField[key]
          "Port returned a value that failed to decode at #{location}: missing field `#{key}` (#{value.inspect})"

        in Jade::Decode::Custom[msg]
          "Port returned a value that failed to decode at #{location}: #{msg} (#{value.inspect})"

        in Jade::Decode::Multiple[errors]
          errors
            .map { format(it, value) }
            .join("; ")
        end
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

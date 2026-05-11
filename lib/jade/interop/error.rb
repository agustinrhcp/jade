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

    # Raised when Ruby tries to call a Jade function whose signature can't
    # cross the boundary — typically a polymorphic function whose constrained
    # type variable has no extractable witness in the args (function-typed
    # arg, return-position-only var, etc.). Internal Jade callers are
    # unaffected; they go through the impl-synthetic with an inline dict.
    class NotCallableFromRuby < Error
      def initialize(function_qname, cause)
        super(
          "Cannot call #{function_qname} from Ruby: #{cause}. " \
            "Internal Jade callers still work; if Ruby needs this, write a " \
            "monomorphizing Jade-side wrapper."
        )
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

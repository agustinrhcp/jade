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
  end
end

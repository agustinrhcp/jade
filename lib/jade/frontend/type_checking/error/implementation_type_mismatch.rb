module Jade
  module Frontend
    module TypeChecking
      module Error
        class ImplementationTypeMismatch < TypeMismatch
          def initialize(entry, span, expected:, actual:, interface:, fn_name:)
            super(entry, span, expected:, actual:)
            @interface = interface
            @fn_name   = fn_name
          end

          def message
            "Implementation of #{@interface}.#{@fn_name}: " \
              "expected #{naming[@expected]} but the provided function has type #{naming[@actual]}"
          end
        end
      end
    end
  end
end

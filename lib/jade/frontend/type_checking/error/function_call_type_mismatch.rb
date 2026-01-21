module Jade
  module Frontend
    module TypeChecking
      module Error
        class FunctionCallTypeMismatch < TypeMismatch
          def initialize(entry, span, expected:, actual:)
            super
          end

          def message
            "Function call mismatch, expected #{@expected} but found #{@actual}"
          end
        end
      end
    end
  end
end

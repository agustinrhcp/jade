module Jade
  module Frontend
    module TypeChecking
      module Error
        class IfBranchesTypeMismatch < TypeMismatch
          def initialize(entry, span, expected:, actual:)
            super
          end

          def message
            "If branches must return the same type. The then branch produces " +
              "#{naming[@expected]} but the else branch produces #{naming[@actual]}"
          end
        end
      end
    end
  end
end

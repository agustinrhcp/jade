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
              "#{@expected} but the else branch produces #{@actual}"
          end
        end
      end
    end
  end
end

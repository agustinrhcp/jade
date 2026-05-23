module Jade
  module Frontend
    module TypeChecking
      module Error
        class CaseOfBranchesTypeMismatch < Error::TypeMismatch
          def initialize(entry, span, expected:, actual:, actual_index:)
            super
            @actual_index = actual_index
          end

          def message
            "First branch of this case statement is #{@expected} " +
              "but #{ordinal(@actual_index)} branch is #{@actual}"
          end
        end
      end
    end
  end
end

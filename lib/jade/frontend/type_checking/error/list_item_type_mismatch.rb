module Jade
  module Frontend
    module TypeChecking
      module Error
        class ListItemTypeMismatch < TypeMismatch
          def initialize(entry, span, expected:, actual:, actual_index:)
            super
            @actual_index = actual_index
          end

          def message
            "The #{ordinal(@actual_index)} item does not match the previous items in the list, " +
              "expected #{@expected} but found #{@actual}"
          end
        end
      end
    end
  end
end

module Jade
  module Frontend
    module TypeChecking
      module Error
        class IfConditionTypeMismatch < TypeMismatch
          def initialize(entry, span, expected: Type.bool, actual:)
            super
          end

          def message
            "If condition expects #{naming[@expected]} but found #{naming[@actual]}"
          end
        end
      end
    end
  end
end

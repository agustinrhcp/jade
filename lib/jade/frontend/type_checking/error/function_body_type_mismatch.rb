module Jade
  module Frontend
    module TypeChecking
      module Error
        class FunctionBodyTypeMismatch < TypeMismatch
          def initialize(entry, span, expected:, actual:, function_name:)
            super
            @function_name = function_name
          end

          def message
            "There's a problem with the body of `#{@function_name}` definition: " ++
              "it returns #{@actual} but its signature says it should be #{@expected}"
          end

          def label
            "returns #{@actual}, expected #{@expected}"
          end
        end
      end
    end
  end
end

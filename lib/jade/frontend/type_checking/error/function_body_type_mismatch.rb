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
            "There\u0027s a problem with the body of `#{@function_name}` definition: " \
              "it returns #{naming.annotated(@actual)} but its signature says it should be " \
              "#{naming.annotated(@expected)}"
          end

          def label
            "returns #{naming[@actual]}, expected #{naming[@expected]}"
          end
        end
      end
    end
  end
end

module Jade
  module Frontend
    module TypeChecking
      module Inference
        module Body
          extend Helpers
          extend self

          def infer(node, registry, state, expected)
            node => AST::Body(expressions:)

            *first_expressions, last_expression = expressions

            first_expressions_state = first_expressions
              .reduce(state) do |acc, expr|
                new_state, _ = check(expr, registry, acc, Expected.non_auth(state.fresh))
                new_state
              end

            check(last_expression, registry, first_expressions_state, expected)
          end
        end
      end
    end
  end
end


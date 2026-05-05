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

            first_state, first_cs = first_expressions
              .reduce([state, []]) do |(acc, cs), expr|
                new_state, result = check(
                  expr,
                  registry,
                  acc,
                  Expected.infer(state.fresh),
                )
                [new_state, cs + result.constraints]
              end

            last_state, last_result = check(
              last_expression,
              registry,
              first_state,
              expected,
            )

            first_cs
              .map { last_state.env.substitution.apply(it) }
              .then do
                last_result
                  .with(constraints: it + last_result.constraints)
                  .then { |result| [last_state, result] }
              end
          end
        end
      end
    end
  end
end


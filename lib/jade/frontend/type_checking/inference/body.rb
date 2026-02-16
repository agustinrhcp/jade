module Jade
  module Frontend
    module TypeChecking
      module Inference
        module Body
          extend Helpers
          extend self

          def infer(node, registry, env, expected)
            node => AST::Body(expressions:)

            *first_expressions, last_expression = expressions

            first_expressions_result = first_expressions
              .reduce(Result[Type.unit, Substitution.new, env, []]) do |acc, expr|
                check(expr, registry, acc.env, Expected.non_auth(env.fresh))
                  .add_errors(acc.errors)
                  .compose_substitution(acc.substitution)
              end

            check(last_expression, registry, first_expressions_result.env, expected)
              .compose_substitution(first_expressions_result.substitution)
              .add_errors(first_expressions_result.errors)
          end
        end
      end
    end
  end
end


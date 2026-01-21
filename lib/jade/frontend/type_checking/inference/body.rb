module Jade
  module Frontend
    module TypeChecking
      module Inference
        module Body
          extend Helpers
          extend self

          def infer(node, registry, env, var_gen, expected)
            node => AST::Body(expressions:)

            *first_expressions, last_expression = expressions

            first_expressions_result = first_expressions
              .reduce(Result[Type.unit, Substitution.new, env, []]) do |acc, expr|
                check(expr, registry, acc.env, var_gen, Expected.non_auth(var_gen))
                  .add_errors(acc.errors)
                  .compose_substitution(acc.substitution)
              end

            check(last_expression, registry, first_expressions_result.env, var_gen, expected)
              .compose_substitution(first_expressions_result.substitution)
              .add_errors(first_expressions_result.errors)
          end
        end
      end
    end
  end
end


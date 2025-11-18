module Jade
  module Frontend
    module TypeChecking
      module Inference
        module InfixApplication
          extend Helpers
          extend self

          def infer(node, registry, env, var_gen)
            node => AST::InfixApplication(operator:, left:, right:)

            fn_type = type_from_symbol(operator.symbol, registry)

            left_expected_type, right_expected_type = fn_type.args.values

            left_result = check(left, registry, env, var_gen)
              .and_unify(left_expected_type) do
                InfixApplicationTypeMismatchError.new(node, it.expected, it.actual, :left)
              end

            right_result = check(right, registry, left_result.env, var_gen)
              .and_unify(right_expected_type) do
                InfixApplicationTypeMismatchError.new(node, it.expected, it.actual, :left)
              end

            Result[
              fn_type.return_type,
              left_result.substitution.compose(right_result.substitution), 
              right_result.env,
              left_result.errors + right_result.errors,
            ]
          end
        end
      end
    end
  end
end


module Jade
  module Frontend
    module TypeChecking
      module Inference
        module InfixApplication
          extend Helpers
          extend self

          def infer(node, registry, env, expected)
            node => AST::InfixApplication(operator:, left:, right:)

            fn_type = env.lookup(operator.symbol.qualified_name)
              .then { instantiate(it, env.var_gen) }

            left_expected_type, right_expected_type = fn_type.args

            left_result = check(left, registry, env, expected)
              .and_unify(left_expected_type) do
                Error::InfixApplicationTypeMismatch.new(
                  env.entry_name,
                  left.range,
                  expected: it.expected,
                  actual: it.actual,
                  side: :left,
                  operator: operator.value,
                )
              end

            right_result = check(right, registry, left_result.env, expected)
              .and_unify(right_expected_type) do
                Error::InfixApplicationTypeMismatch.new(
                  env.entry_name,
                  right.range,
                  expected: it.expected,
                  actual: it.actual,
                  side: :right,
                  operator: operator.value,
                )
              end

            final_substitution =
              left_result.substitution.compose(right_result.substitution)

            constraints =
              final_substitution.apply(fn_type).constraints

            # mutates the node
            node.dictionaries.concat(constraints)

            Result[
              fn_type.return_type,
              final_substitution, 
              right_result.env,
              left_result.errors + right_result.errors,
            ]
              .and_unify(expected.type)
          end
        end
      end
    end
  end
end


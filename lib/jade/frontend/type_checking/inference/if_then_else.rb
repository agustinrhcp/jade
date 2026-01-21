module Jade
  module Frontend
    module TypeChecking
      module Inference
        module IfThenElse
          extend Helpers
          extend self

          def infer(node, registry, env, var_gen, expected)
            node => AST::IfThenElse(condition:, if_branch:, else_branch:)

            condition_result = check(condition, registry, env, var_gen, Expected.auth(Type.bool))
              .and_unify(Type.bool) do
                Error::IfConditionTypeMismatch.new(
                  env.entry_name,
                  condition.range,
                  actual: it.actual,
                )
              end

            if_result = check(if_branch, registry, condition_result.env, var_gen, expected)
              .compose_substitution(condition_result.substitution)

            else_result = check(else_branch, registry, condition_result.env, var_gen, expected)
              .compose_substitution(condition_result.substitution)

            if expected.auth?
              if_result_unified = if_result
                .and_unify(expected.type) do
                  IfBranchTypeMismatch.new(
                    env.entry_name,
                    if_branch.range,
                    expected: it.expected,
                    actual: it.actual,
                    branch: :then,
                  )
                end

              else_result
                .and_unify(expected.type) do
                  IfBranchTypeMismatch.new(
                    env.entry_name,
                    else_branch.range,
                    expected: it.expected,
                    actual: it.actual,
                    branch: :else,
                  )
                end
                .compose_substitution(if_result_unified.substitution)
                .add_errors(condition_result.errors)
                .add_errors(if_result_unified.errors)

            else
              else_result
                .and_unify(if_result.type) do
                  Error::IfBranchesTypeMismatch.new(
                    env.entry_name,
                    else_branch.range,
                    expected: it.expected,
                    actual: it.actual,
                  )
                end
                .and_unify(expected.type)
                .add_errors(condition_result.errors)
                .add_errors(if_result.errors)
            end
          end
        end
      end
    end
  end
end

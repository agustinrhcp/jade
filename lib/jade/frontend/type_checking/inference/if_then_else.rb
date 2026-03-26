module Jade
  module Frontend
    module TypeChecking
      module Inference
        module IfThenElse
          extend Helpers
          extend self

          def infer(node, registry, state, expected)
            node => AST::IfThenElse(condition:, if_branch:, else_branch:)

            cond_state, cond_result = check(condition, registry, state, Expected.check(Type.bool))
            after_cond_state, _ = cond_state.unify_result(cond_result, Type.bool) do
              Error::IfConditionTypeMismatch.new(
                state.env.entry_name,
                condition.range,
                actual: it.actual,
              )
            end

            if_state, if_result = check(if_branch, registry, after_cond_state, expected)
            else_state, else_result = check(else_branch, registry, if_state, expected)

            else_state.unify_result(else_result, if_result.type, expected.rigid_vars) do
              Error::IfBranchesTypeMismatch.new(
                state.env.entry_name,
                else_branch.range,
                expected: it.expected,
                actual: it.actual,
              )
            end
          end
        end
      end
    end
  end
end

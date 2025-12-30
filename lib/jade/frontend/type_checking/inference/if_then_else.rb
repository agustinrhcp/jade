module Jade
  module Frontend
    module TypeChecking
      module Inference
        module IfThenElse
          extend Helpers
          extend self

          def infer(node, registry, env, var_gen)
            node => AST::IfThenElse(condition:, if_branch:, else_branch:)

            condition_result = check(condition, registry, env, var_gen)
              .and_unify(Type.bool) do
                IfConditionTypeMismatchError.new(node, it.expected, it.actual)
              end

            if_result = check(if_branch, registry, condition_result.env, var_gen)
            else_result = check(else_branch, registry, condition_result.env, var_gen)

            if_result
              .compose_substitution(condition_result.substitution)
              .compose_substitution(else_result.substitution)
              .and_unify(else_result.type) do
                IfBranchesTypeMismatchError.new(node, it.expected, it.actual)
              end
              .add_errors(condition_result.errors)
              .add_errors(else_result.errors)
          end
        end
      end
    end
  end
end

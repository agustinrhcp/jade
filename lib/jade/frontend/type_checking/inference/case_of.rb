module Jade
  module Frontend
    module TypeChecking
      module Inference
        module CaseOf
          extend Helpers
          extend self

          def infer(node, registry, env, var_gen)
            node => AST::CaseOf(expression:, branches:)

            expression_result = check(expression, registry, env, var_gen)

            first_branch, *rest = branches
              .map do |br|
                br => AST::CaseOfBranch(pattern:, body:)

                pattern_result = check(pattern, registry, env, var_gen)
                  .compose_substitution(expression_result.substitution)
                  .and_unify(expression_result.type)

                check(body, registry, pattern_result.env, var_gen)
                  .compose_substitution(pattern_result.substitution)
                  .add_errors(pattern_result.errors)
              end

            rest
              .each_with_index.reduce(first_branch) do |acc, (branch, i)|
                acc
                  .compose_substitution(branch.substitution)
                  .add_errors(branch.errors)
                  .and_unify(branch.type)
              end
          end
        end
      end
    end
  end
end

require 'jade/frontend/pattern_analysis'

module Jade
  module Frontend
    module TypeChecking
      module Inference
        module CaseOf
          extend Helpers
          extend self

          def infer(node, registry, state, expected)
            node => AST::CaseOf(expression:, branches:)

            new_state, expr_result = check(expression, registry, state, Expected.infer(state.fresh))

            first_branch, *rest_branches = branches
            after_first_state, first_result = infer_branch(
              first_branch,
              registry,
              new_state,
              expected,
              expr_result,
            )

            rest_branches
              .each_with_index
              .reduce(after_first_state) do |acc, (branch, i)|
                new_acc, type = infer_branch(branch, registry, acc, expected, expr_result)
                new_acc.unify(type.type, first_result.type) do
                  Error::CaseOfBranchesTypeMismatch
                    .new(new_acc.env.entry_name, branch.range, actual: it.actual, expected: it.expected, actual_index: i + 2)
                end
              end
              .then { check_exhaustiveness(node, it, registry, expr_result) }
              .then { [it, first_result.apply(it.env.substitution)] }
          end

          private

          def check_exhaustiveness(node, state, registry, result)
            node => AST::CaseOf(branches:)
            PatternAnalysis::Exhaustiveness
              .assert(branches.map(&:pattern), node.range, state.env, registry, result.type)
              .then { state.add_errors(it) }
          end

          def infer_branch(node, registry, env, expected, expression_result)
            node => AST::CaseOfBranch(pattern:, body:)

            pattern_state, _pattern_result = Pattern.infer(
              pattern, registry, env, Expected.infer(expression_result.type)
            )

            check(body, registry, pattern_state, expected)
          end
        end
      end
    end
  end
end

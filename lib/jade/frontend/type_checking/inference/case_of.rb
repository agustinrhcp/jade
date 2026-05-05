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

            new_state, expr_result = check(
              expression,
              registry,
              state,
              Expected.infer(state.fresh),
            )

            first_branch, *rest_branches = branches
            after_first_state, first_result = infer_branch(
              first_branch,
              registry,
              new_state,
              expected,
              expr_result,
            )

            seed = [
              after_first_state,
              expr_result.constraints + first_result.constraints
            ]

            rest_branches
              .each_with_index
              .reduce(seed) do |(acc, cs), (branch, i)|
                unify_branch(
                  branch,
                  i,
                  acc,
                  first_result,
                  cs,
                  registry,
                  expected,
                  expr_result,
                )
              end
              .then { |st, cs| [check_exhaustiveness(node, st, registry, expr_result), cs] }
              .then do |st, cs|
                first_result
                  .with(constraints: cs)
                  .apply(st.env.substitution)
                  .then { |result| [st, result] }
              end
          end

          private

          def unify_branch(branch, i, state, first_result, cs, registry, expected, expr_result)
            new_state, body = infer_branch(branch, registry, state, expected, expr_result)

            new_state
              .unify(body.type, first_result.type) { branch_mismatch(new_state, branch, it, i) }
              .then { [it, cs + body.constraints] }
          end

          def branch_mismatch(state, branch, error, index)
            Error::CaseOfBranchesTypeMismatch.new(
              state.env.entry_name,
              branch.range,
              actual: error.actual,
              expected: error.expected,
              actual_index: index + 2,
            )
          end

          def check_exhaustiveness(node, state, registry, result)
            node => AST::CaseOf(branches:)

            patterns = branches.map(&:pattern)
            type     = result.apply(state.env.substitution).type

            PatternAnalysis::Exhaustiveness
              .assert(patterns, node.range, state.env, registry, type)
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

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
            PatternAnalysis::Exhaustiveness
              .assert(node, state.env, registry, result.type)
              .then { state.add_errors(it) }
          end

          def infer_branch(node, registry, env, expected, expression_result)
            node => AST::CaseOfBranch(pattern:, body:)

            pattern_state, _pattern_result = infer_pattern(
              pattern, registry, env, Expected.infer(expression_result.type)
            )

            check(body, registry, pattern_state, expected)
          end

          def infer_pattern(pattern, registry, state, expected)
            case pattern
            in AST::Pattern::Record(fields:, symbol:)
              fields_state, fields_result = fields
                .reduce([state, Result.accumulator]) do |(state_acc, result_acc), field|
                  st, rs = infer_pattern(field.pattern, registry, state_acc, Expected.infer(state_acc.fresh))
                  [st, result_acc.add(rs)]
                end

              fields
                .map(&:name)
                .zip(fields_result.types)
                .to_h
                .then { Type.anonymous_record(it, state.fresh) }
                .then { Result.init(it) }
                .then { fields_state.unify_result(it, expected.type, &type_error(state, pattern)) }

            in AST::Pattern::Literal(literal:)
              new_state, literal_result = check(literal, registry, state, expected)
              new_state.unify_result(literal_result, expected.type, &type_error(state, pattern))

            in AST::Pattern::Wildcard
              Result
                .init(state.fresh)
                .then { state.unify_result(it, expected.type) }

            in AST::Pattern::Binding(name:)
              state
                .bind(name, generalize(state.env, expected.type))
                .then { it.unify_result(Result.init(it.fresh), expected.type) }

            in AST::Pattern::Constructor(symbol:, patterns:)
              state.env.lookup(symbol.qualified_name) => { type: constructor_type }

              patterns_state, patterns_result = constructor_type
                .args
                .zip(patterns)
                .reduce([state, Result.accumulator]) do |(acc_state, acc_result), (inner_expected, pattern)|
                  new_state, result = infer_pattern(pattern, registry, acc_state, Expected.check(inner_expected))
                  [new_state, acc_result.add(result)]
                end

              patterns_result.types
                .then { Type.function(it, expected.type) }
                .then { Result.init(it) }
                .then do
                   patterns_state
                    .unify_result(it, constructor_type) do |error|
                      Error::PatternTypeMismatch.new(
                        state.env.entry_name, pattern.range,
                        expected: error.expected.return_type,
                        actual: error.actual.return_type,
                      )
                    end
                 end
                .then { |(state, result)| [state, result.map(&:return_type)] }
            end
          end

          def type_error(state, pattern)
            ->(error) do
              Error::PatternTypeMismatch.new(
                state.env.entry_name, pattern.range,
                expected: error.expected, actual: error.actual,
              )
            end
          end
        end
      end
    end
  end
end

require 'jade/frontend/pattern_analysis'

module Jade
  module Frontend
    module TypeChecking
      module Inference
        module CaseOf
          extend Helpers
          extend self

          def infer(node, registry, env, expected)
            node => AST::CaseOf(expression:, branches:)

            expression_result = check(expression, registry, env, Expected.non_auth(env.fresh))

            first_branch, *rest_branches = branches
            first_result = infer_branch(
              first_branch,
              registry,
              expression_result.env,
              expected,
              expression_result,
            ).and_unify(expected.type)

            rest_branches
              .each_with_index
              .reduce(first_result) do |acc, (branch, i)|
                infer_branch(branch, registry, expression_result.env, expected, expression_result)
                  .and_unify(acc.type) do
                    Error::CaseOfBranchesTypeMismatch.new(env.entry_name, branch.range, actual: it.actual, expected: it.expected, actual_index: i + 2)
                  end
                  .compose_substitution(acc.substitution)
                  .add_errors(acc.errors)
              end
              .with(type: first_result.type)
              .add_errors(PatternAnalysis::Exhaustiveness.assert(node, env, registry, expression_result.type))
          end

          private

          def infer_branch(node, registry, env, expected, expression_result)
            node => AST::CaseOfBranch(pattern:, body:)

            pattern_result = infer_pattern(pattern, registry, env, Expected.auth(expression_result.type))
              .compose_substitution(expression_result.substitution)
              .and_unify(expression_result.type) do
                Error::PatternTypeMismatch.new(
                  env.entry_name, pattern.range,
                  expected: it.expected, actual: it.actual,
                )
              end

            check(body, registry, pattern_result.env, expected)
              .compose_substitution(pattern_result.substitution)
              .add_errors(pattern_result.errors)
          end

          def infer_pattern(pattern, registry, env, expected)
            case pattern
            in AST::Pattern::Record(fields:, symbol:)
              fields_result = fields
                .reduce(Result.new([], Substitution.new, env, [])) do |acc, field|
                  infer_pattern(field.pattern, registry, acc.env, Expected.non_auth(env.fresh))
                    .then { it.with(type: acc.type + [it.type]) }
                    .compose_substitution(acc.substitution)
                    .add_errors(acc.errors)
                end

              fields
                .map(&:name)
                .zip(fields_result.type)
                .to_h
                .then { Type.anonymous_record(it, env.fresh) }
                .then { fields_result.with(type: it) }

            in AST::Pattern::Literal(literal:)
              check(literal, registry, env, expected)
                .and_unify(expected.type) do
                  Error::PatternTypeMismatch.new(
                    env.entry_name, pattern.range,
                    expected: it.expected, actual: it.actual,
                  )
                end

            in AST::Pattern::Wildcard
              Result[env.fresh, Substitution.new, env, []]
                .and_unify(expected.type)

            in AST::Pattern::Binding(name:)
              Result[
                env.fresh,
                Substitution.new,
                env.bind(name, generalize(env, expected.type)),
                [],
              ].and_unify(expected.type)

            in AST::Pattern::Constructor(symbol:, patterns:)
              constructor_type = env.lookup(symbol.qualified_name)
                .then { instantiate(it, env.var_gen) }

              patterns_result = constructor_type
                .args
                .zip(patterns)
                .reduce(Result.new([], Substitution.new, env, [])) do |acc, (inner_expected, pattern)|
                  infer_pattern(pattern, registry, acc.env, Expected.auth(inner_expected))
                    .then { it.with(type: acc.type + [it.type]) }
                    .compose_substitution(acc.substitution)
                    .add_errors(acc.errors)
                end

              constructor_type
                .then { patterns_result.substitution.apply(it).return_type }
                .then { patterns_result.with(type: it ) }
                .and_unify(expected.type)
            end
          end
        end
      end
    end
  end
end

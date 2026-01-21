module Jade
  module Frontend
    module TypeChecking
      module Inference
        module CaseOf
          extend Helpers
          extend self

          def infer(node, registry, env, var_gen, expected)
            node => AST::CaseOf(expression:, branches:)

            expression_result = check(expression, registry, env, var_gen, Expected.non_auth(var_gen))

            first_branch, *rest_branches = branches
            first_result = infer_branch(
              first_branch,
              registry,
              expression_result.env,
              var_gen,
              expected,
              expression_result,
            ).and_unify(expected.type)


            rest_branches
              .each_with_index
              .reduce(first_result) do |acc, (branch, i)|
                infer_branch(branch, registry, expression_result.env, var_gen, expected, expression_result)
                  .and_unify(acc.type) do
                    Error::CaseOfBranchesTypeMismatch.new(env.entry_name, branch.range, actual: it.actual, expected: it.expected, actual_index: i + 2)
                  end
                  .compose_substitution(acc.substitution)
                  .add_errors(acc.errors)
              end
              .with(type: first_result.type)
          end

          def infer_branch(node, registry, env, var_gen, expected, expression_result)
            node => AST::CaseOfBranch(pattern:, body:)

            pattern_result = infer_pattern(pattern, registry, env, var_gen, Expected.auth(expression_result.type))
              .compose_substitution(expression_result.substitution)
              .and_unify(expression_result.type) do
                Error::PatternTypeMismatch.new(
                  env.entry_name, pattern.range,
                  expected: it.expected, actual: it.actual,
                )
              end

            check(body, registry, pattern_result.env, var_gen, expected)
              .compose_substitution(pattern_result.substitution)
              .add_errors(pattern_result.errors)
          end

          def infer_pattern(pattern, registry, env, var_gen, expected)
            case pattern
            in AST::Pattern::Literal(literal:)
              check(literal, registry, env, var_gen, expected)

            in AST::Pattern::Wildcard
              Result[var_gen.fresh, Substitution.new, env, []]
                .and_unify(expected.type)

            in AST::Pattern::Binding(name:)
              Result[
                var_gen.fresh,
                Substitution.new,
                env.bind(name, generalize(env, expected.type)),
                [],
              ].and_unify(expected.type)

            in AST::Pattern::Constructor(symbol:, patterns:)
              constructor_type = env.lookup(symbol.qualified_name)
                .then { instantiate(it, var_gen) }

              patterns_result = constructor_type
                .args
                .zip(patterns)
                .reduce(Result.new([], Substitution.new, env, [])) do |acc, (inner_expected, pattern)|
                  infer_pattern(pattern, registry, acc.env, var_gen, Expected.auth(inner_expected))
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

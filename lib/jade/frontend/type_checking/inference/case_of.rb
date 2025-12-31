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

                pattern_result = infer_pattern(pattern, expression_result.type, registry, env, var_gen)
                  .compose_substitution(expression_result.substitution)
                  .and_unify(expression_result.type) do
                    PatternTypeMismatchError.new(node, it.expected, it.actual)
                  end

                check(body, registry, pattern_result.env, var_gen)
                  .compose_substitution(pattern_result.substitution)
                  .add_errors(pattern_result.errors)
              end

            rest
              .each_with_index.reduce(first_branch) do |acc, (branch, i)|
                acc
                  .compose_substitution(branch.substitution)
                  .add_errors(branch.errors)
                  .and_unify(branch.type) do
                    CaseOfBranchesTypeMismatchError.new(node, it.actual, it.expected, i + 2)
                  end
              end
          end

          def infer_pattern(pattern, matched_type, registry, env, var_gen)
            case pattern
            in AST::Pattern::Literal(literal:)
              check(literal, registry, env, var_gen)

            in AST::Pattern::Wildcard
              Result[Type.var(var_gen.fresh), Substitution.new, env, []]

            in AST::Pattern::Binding(name:)
              Result[
                Type.var(var_gen.fresh),
                Substitution.new,
                env.bind(name, generalize(matched_type)),
                [],
              ].and_unify(matched_type)

            in AST::Pattern::Constructor(symbol:, patterns:)
              constructor_type = type_from_symbol(symbol, registry)

              patterns_result = constructor_type
                .args.zip(patterns)
                .reduce(Result.new([], Substitution.new, env, [])) do |acc, (expected, pattern)|
                  infer_pattern(pattern, expected, registry, acc.env, var_gen)
                    .then { it.with(type: acc.type + [it.type]) }
                    .compose_substitution(acc.substitution)
                    .add_errors(acc.errors)
                end

              constructor_type
                .then { generalize(it) }
                .then { instantiate(it, var_gen) }
                .then { patterns_result.substitution.apply(it).return_type }
                .then { patterns_result.with(type: it ) }
            end
          end
        end
      end
    end
  end
end

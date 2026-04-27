require 'jade/frontend/pattern_analysis'

module Jade
  module Frontend
    module TypeChecking
      module Inference
        module Assign
          extend Helpers
          extend self

          def infer(node, registry, state, expected)
            node => AST::Assign(pattern:, expression:)

            expr_state, expr_result = check(
              expression,
              registry,
              state,
              Expected.infer(state.fresh),
            )

            pattern_state, _ = Pattern.infer(
              pattern,
              registry,
              expr_state,
              Expected.check(expr_result.type),
            )

            final_state =
              case pattern
              in AST::Pattern::Binding(name:)
                pattern_state
                  .env
                  .substitution
                  .then do |sub|
                    pattern_state.bind(name, generalize(
                      expr_state.env,
                      sub.apply(expr_result.type),
                      expr_result.constraints.map { sub.apply(it) },
                    ))
                  end
              else
                pattern_state
              end

            PatternAnalysis::Exhaustiveness
              .assert([pattern], pattern.range, final_state.env, registry, expr_result.type)
              .then { final_state.add_errors(it) }
              .unify_result(expr_result, expected.type)
          end
        end
      end
    end
  end
end

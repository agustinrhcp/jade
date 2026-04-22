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

            PatternAnalysis::Exhaustiveness
              .assert([pattern], pattern.range, pattern_state.env, registry, expr_result.type)
              .then { pattern_state.add_errors(it) }
              .unify_result(expr_result, expected.type)
          end
        end
      end
    end
  end
end

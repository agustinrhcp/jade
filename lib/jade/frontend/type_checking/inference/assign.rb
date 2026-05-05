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

            final_state, residual_cs =
              case pattern
              in AST::Pattern::Binding(name:)
                bind_with_residual(pattern_state, expr_state, expr_result, name)
              else
                [pattern_state, expr_result.constraints]
              end

            PatternAnalysis::Exhaustiveness
              .assert([pattern], pattern.range, final_state.env, registry, expr_result.type)
              .then { final_state.add_errors(it) }
              .unify_result(expr_result.with(constraints: residual_cs), expected.type)
          end

          private

          # Constraints whose vars are quantified into the new binding's scheme
          # are captured by it; the rest propagate to the enclosing scope.
          def bind_with_residual(pattern_state, expr_state, expr_result, name)
            result = expr_result.apply(pattern_state.env.substitution)
            scheme = generalize(expr_state.env, result.type, result.constraints)

            result.constraints
              .reject { |c| c.unbound_vars.any? { |v| scheme.quantified.any? { it.id == v.id } } }
              .then { [pattern_state.bind(name, scheme), it] }
          end
        end
      end
    end
  end
end

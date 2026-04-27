module Jade
  module Frontend
    module TypeChecking
      module Inference
        module Lambda
          extend Helpers
          extend self

          def infer(node, registry, state, expected)
            node => AST::Lambda(body:, params:)

            params_types = params.map { state.fresh }

            pre_state = state
              .unify_result(
                Result.init(Type.function(params_types, state.fresh)),
                expected.type,
              )
              .first

            params_state = params
              .zip(params_types)
              .reduce(pre_state) do |acc, (p, t)|
                case p
                in AST::Pattern::Binding(name:)
                  pre_state.env.substitution.apply(t)
                    .then { acc.bind(name, Scheme.mono(it)) }

                in AST::Pattern::Wildcard
                  acc

                else
                  pre_state.env.substitution.apply(t)
                    .then { Pattern.infer(p, registry, acc, Expected.check(it)) }
                    .first
                end
              end

            body_state, body_result = check(
              body,
              registry,
              params_state,
              Expected.infer(params_state.fresh),
            )

            exhaustiveness_state = params
              .zip(params_types)
              .reduce(body_state) do |acc, (p, t)|
                case p
                in AST::Pattern::Binding | AST::Pattern::Wildcard
                  acc
                else
                  concrete_t = body_state.env.substitution.apply(t)
                  PatternAnalysis::Exhaustiveness
                    .assert([p], p.range, acc.env, registry, concrete_t)
                    .then { acc.add_errors(it) }
                end
              end

            Type
              .function(params_types, body_result.type)
              .then { Result.init(it, body_result.constraints) }
              .apply(exhaustiveness_state.env.substitution)
              .then { exhaustiveness_state.unify_result(it, expected.type) }
          end
        end
      end
    end
  end
end

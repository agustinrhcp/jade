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
                Scheme
                  .mono(pre_state.env.substitution.apply(t))
                  .then { acc.bind(p.name, it) }
              end

            body_state, body_result = check(
              body,
              registry,
              params_state,
              Expected.infer(params_state.fresh),
            )

            Type
              .function(params_types, body_result.type)
              .then { Result.init(it) }
              .apply(body_state.env.substitution)
              .then { body_state.unify_result(it, expected.type) }
          end
        end
      end
    end
  end
end

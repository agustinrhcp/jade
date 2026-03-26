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

            params_state = params
              .zip(params_types)
              .reduce(state) { |acc, (p, t)| acc.bind(p.name, Scheme.mono(t)) }

            body_state, body_result = check(
              body, registry, params_state, Expected.infer(params_state.fresh),
            )

            fn_type = Type.function(params_types, body_result.type)
            result = Result.init(fn_type).apply(body_state.env.substitution)

            body_state.unify_result(result, expected.type)
          end
        end
      end
    end
  end
end

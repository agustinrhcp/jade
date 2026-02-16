module Jade
  module Frontend
    module TypeChecking
      module Inference
        module Lambda
          extend Helpers
          extend self

          def infer(node, registry, env, expected)
            node => AST::Lambda(body:, params:)

            params_types = params.map { env.fresh }

            params
              .zip(params_types)
              .reduce(env) { |body_env, (p, t)| body_env.bind(p.name, generalize(env, t)) }
              .then { check(body, registry, it, Expected.non_auth(env.fresh)) }
              .then do |r|
                Type.function(params_types, r.type)
                  .then { r.substitution.apply(it) }
                  .then { r.with(type: it) }
              end
              .then { it.with(env:) }
              .and_unify(expected.type)
          end
        end
      end
    end
  end
end

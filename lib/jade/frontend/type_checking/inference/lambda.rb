module Jade
  module Frontend
    module TypeChecking
      module Inference
        module Lambda
          extend Helpers
          extend self

          def infer(node, registry, env, var_gen, expected)
            node => AST::Lambda(body:, params:)

            params_types = params.map { var_gen.fresh }

            params
              .zip(params_types)
              .reduce(env) { |body_env, (p, t)| body_env.bind(p.name, generalize(env, t)) }
              .then { check(body, registry, it, var_gen, Expected.non_auth(var_gen)) }
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

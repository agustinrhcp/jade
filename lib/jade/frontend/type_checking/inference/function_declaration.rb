module Jade
  module Frontend
    module TypeChecking
      module Inference
        module FunctionDeclaration
          extend Helpers
          extend self

          def infer(node, registry, env, _)
            node => AST::FunctionDeclaration(symbol:, body:, params:)

            fn_type = env.lookup(symbol.qualified_name).then { instantiate(it, env.var_gen) }

            fn_type
              .args
              .zip(params)
              .reduce(env) do |body_env, (t, p)|
                body_env.bind(p.name, Scheme[[], t, fn_type.constraints])
              end
              .then { check(body, registry, it, Expected.auth(fn_type.return_type)) }
              .and_unify(fn_type.return_type.make_rigid) do |error|
                Error::FunctionBodyTypeMismatch.new(
                  env.entry_name,
                  node.range,
                  expected: error.expected,
                  actual: error.actual,
                  function_name: node.name,
                )
              end
              .then { it.with(type: Type.unit) }
          end
        end
      end
    end
  end
end

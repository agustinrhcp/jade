module Jade
  module Frontend
    module TypeChecking
      module Inference
        module FunctionDeclaration
          extend Helpers
          extend self

          def infer(node, registry, env, var_gen)
            node => AST::FunctionDeclaration(symbol:, body:)

            fn_type = type_from_symbol(symbol, registry)

            fn_type
              .args.reduce(env) { |body_env, (k, v)| body_env.bind(k, generalize(v)) }
              .then { check(body, registry, it, var_gen) }
              .and_unify(fn_type.return_type) do |error|
                FunctionBodyTypeMismatchError.new(node, error.expected, error.actual)
              end
              .then { it.with(type: Type.unit) }
              .then { it.with(env: env.bind(node.name, generalize(fn_type))) }
          end
        end
      end
    end
  end
end

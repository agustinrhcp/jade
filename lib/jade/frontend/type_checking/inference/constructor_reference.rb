module Jade
  module Frontend
    module TypeChecking
      module Inference
        module ConstructorReference
          extend Helpers
          extend self

          def infer(node, registry, env, expected)
            node => AST::ConstructorReference(symbol:)

            env
              .bindings[symbol.qualified_name]
              .then { instantiate(it, env.var_gen) }
              .then { |(type, constraints)| Result.init(type.first, env, constraints) }
              .and_unify(expected.type)
          end
        end
      end
    end
  end
end

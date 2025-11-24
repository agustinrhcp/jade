module Jade
  module Frontend
    module TypeChecking
      module Inference
        module ConstructorReference
          extend Helpers
          extend self

          def infer(node, registry, env, var_gen)
            node => AST::ConstructorReference(symbol:)

            env.bindings[node.name]
              .then { instantiate(it, var_gen) }
              .then { Result.new(it, Substitution.new, env, []) }
          end
        end
      end
    end
  end
end

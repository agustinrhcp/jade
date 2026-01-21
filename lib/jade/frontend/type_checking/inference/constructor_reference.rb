module Jade
  module Frontend
    module TypeChecking
      module Inference
        module ConstructorReference
          extend Helpers
          extend self

          def infer(node, registry, env, var_gen, expected)
            node => AST::ConstructorReference(symbol:)

            env
              .bindings[symbol.qualified_name]
              .then { instantiate(it, var_gen) }
              .then { Result.new(it, Substitution.new, env, []) }
              .and_unify(expected.type)
          end
        end
      end
    end
  end
end

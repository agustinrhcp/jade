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
              .lookup(symbol.qualified_name)
              .then { |(type, cons)| Result.init(type, env, cons) }
              .and_unify(expected.type)
          end
        end
      end
    end
  end
end

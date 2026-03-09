module Jade
  module Frontend
    module TypeChecking
      module Inference
        module VariableReference
          extend Helpers
          extend self

          def infer(node, registry, env, _)
            node => AST::VariableReference(symbol:)
        
            case symbol
            in Symbol::Variable
              env.bindings[symbol.name]
            else
              env.bindings[symbol.qualified_name]
            end
              .then { instantiate(it, env.var_gen) }
              .then { |(type, cons)| Result.init(type, env, cons) }
          end
        end
      end
    end
  end
end


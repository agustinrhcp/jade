module Jade
  module Frontend
    module TypeChecking
      module Inference
        module VariableReference
          extend Helpers
          extend self

          def infer(node, registry, state, _)
            node => AST::VariableReference(symbol:)
        
            case symbol
            in Symbol::Variable
              state.env.lookup(symbol.name)
            else
              state.env.lookup(symbol.qualified_name)
            end
              .then { [state, Result.init(it)] }
          end
        end
      end
    end
  end
end


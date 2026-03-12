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
              env.lookup(symbol.name)
            else
              env.lookup(symbol.qualified_name)
            end
              .then { |(type, cons)| Result.init(type, env, with_span(node, cons)) }
          end
        end
      end
    end
  end
end


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
              symbol.name
            else
              symbol.qualified_name
            end
              .then { state.env.lookup(it) }
              .then { it.attach_origin(node) }
              .then { [state, it] }
          end
        end
      end
    end
  end
end


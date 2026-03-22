module Jade
  module Frontend
    module TypeChecking
      module Inference
        module InterfaceDeclaration
          extend Helpers
          extend self

          def infer(node, _, state, _)
            node => AST::InterfaceDeclaration

            [state, Result.init(Type.unit)]
          end
        end
      end
    end
  end
end

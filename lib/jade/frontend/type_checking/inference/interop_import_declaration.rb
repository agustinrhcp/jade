module Jade
  module Frontend
    module TypeChecking
      module Inference
        module InteropImportDeclaration
          extend Helpers
          extend self

          def infer(node, _, state, _)
            node => AST::InteropImportDeclaration

            [state, Result.init(Type.unit)]
          end
        end
      end
    end
  end
end

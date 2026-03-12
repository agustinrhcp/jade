module Jade
  module Frontend
    module TypeChecking
      module Inference
        module TypeDeclaration
          extend Helpers
          extend self

          def infer(node, _, state, _)
            node => AST::TypeDeclaration

            [state, Result.init(Type.unit)]
          end
        end
      end
    end
  end
end

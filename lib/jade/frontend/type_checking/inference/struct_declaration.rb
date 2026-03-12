module Jade
  module Frontend
    module TypeChecking
      module Inference
        module StructDeclaration
          extend Helpers
          extend self

          def infer(node, _, state, _)
            node => AST::StructDeclaration

            [state, Result.init(Type.unit)]
          end
        end
      end
    end
  end
end

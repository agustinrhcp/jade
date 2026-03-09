module Jade
  module Frontend
    module TypeChecking
      module Inference
        module TypeDeclaration
          extend Helpers
          extend self

          def infer(node, _, env, _)
            node => AST::TypeDeclaration

            Result.init(Type.unit, env)
          end
        end
      end
    end
  end
end

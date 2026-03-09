module Jade
  module Frontend
    module TypeChecking
      module Inference
        module StructDeclaration
          extend Helpers
          extend self

          def infer(node, _, env, _)
            node => AST::StructDeclaration

            Result.init(Type.unit, env)
          end
        end
      end
    end
  end
end

module Jade
  module Frontend
    module TypeChecking
      module Inference
        module StructDeclaration
          extend Helpers
          extend self

          def infer(node, _, env, _, _)
            node => AST::StructDeclaration

            Result[Type.unit, Substitution.new, env, []]
          end
        end
      end
    end
  end
end

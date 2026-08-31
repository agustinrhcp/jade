module Jade
  module Frontend
    module TypeChecking
      module Inference
        module TypeAliasDeclaration
          extend Helpers
          extend self

          def infer(node, _, state, _)
            node => AST::TypeAliasDeclaration

            [state, Result.init(Type.unit)]
          end
        end
      end
    end
  end
end

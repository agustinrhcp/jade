module Jade
  module Frontend
    module TypeChecking
      module Inference
        module ImportDeclaration
          extend Helpers
          extend self

          def infer(node, _, state, _)
            node => AST::ImportDeclaration
            Type.unit
              .then { Result.init(it) }
              .then { [state, it] }
          end
        end
      end
    end
  end
end

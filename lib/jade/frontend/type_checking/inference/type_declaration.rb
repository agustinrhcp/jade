module Jade
  module Frontend
    module TypeChecking
      module Inference
        module TypeDeclaration
          extend Helpers
          extend self

          def infer(node, registry, env, var_gen, _)
            node => AST::TypeDeclaration(symbol:, variants:)

            Result[Type.unit, Substitution.new, env, []]
          end
        end
      end
    end
  end
end

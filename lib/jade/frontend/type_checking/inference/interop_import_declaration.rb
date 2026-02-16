module Jade
  module Frontend
    module TypeChecking
      module Inference
        module InteropImportDeclaration
          extend Helpers
          extend self

          def infer(_, _, env, _)
            Result[Type.unit, Substitution.new, env, []]
          end
        end
      end
    end
  end
end

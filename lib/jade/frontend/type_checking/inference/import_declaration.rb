module Jade
  module Frontend
    module TypeChecking
      module Inference
        module ImportDeclaration
          extend Helpers
          extend self

          def infer(_, _, env, _, _)
            Result[Type.unit, Substitution.new, env, []]
          end
        end
      end
    end
  end
end

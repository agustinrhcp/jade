module Jade
  module Frontend
    module TypeChecking
      module Inference
        module ImportDeclaration
          extend Helpers
          extend self

          def infer(_, _, env, _)
            Result.init(Type.unit, env)
          end
        end
      end
    end
  end
end

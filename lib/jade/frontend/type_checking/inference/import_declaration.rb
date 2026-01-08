module Jade
  module Frontend
    module TypeChecking
      module Inference
        module ImportDeclaration
          extend Helpers
          extend self

          def infer(node, registry, env, var_gen)
            Result[Type.unit, Substitution.new, env, []]
          end
        end
      end
    end
  end
end

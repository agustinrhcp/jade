module Jade
  module Frontend
    module TypeChecking
      module Inference
        module Grouping
          extend Helpers
          extend self

          def infer(node, registry, env, var_gen)
            node => AST::Grouping(expression:)

            check(expression, registry, env, var_gen)
          end
        end
      end
    end
  end
end

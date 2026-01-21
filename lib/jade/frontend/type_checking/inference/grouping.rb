module Jade
  module Frontend
    module TypeChecking
      module Inference
        module Grouping
          extend Helpers
          extend self

          def infer(node, registry, env, var_gen, expected_type)
            node => AST::Grouping(expression:)

            check(expression, registry, env, var_gen, expected_type)
          end
        end
      end
    end
  end
end

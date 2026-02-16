module Jade
  module Frontend
    module TypeChecking
      module Inference
        module Module
          extend Helpers
          extend self

          def infer(node, registry, env, expected_type)
            node => AST::Module(body:)

            check(body, registry, env, expected_type)
          end
        end
      end
    end
  end
end

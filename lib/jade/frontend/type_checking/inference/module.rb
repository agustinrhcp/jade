module Jade
  module Frontend
    module TypeChecking
      module Inference
        module Module
          extend Helpers
          extend self

          def infer(node, registry, env, var_gen)
            node => AST::Module(body:)

            check(body, registry, env, var_gen)
          end
        end
      end
    end
  end
end

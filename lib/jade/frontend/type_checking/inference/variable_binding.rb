module Jade
  module Frontend
    module TypeChecking
      module Inference
        module VariableBinding
          extend Helpers
          extend self

          def infer(node, registry, env, expected)
            node => AST::VariableBinding(name:, expression:)

            check(expression, registry, env, expected)
              .then { it.with(env: it.env.bind(name, generalize(env, it.type))) }
          end
        end
      end
    end
  end
end


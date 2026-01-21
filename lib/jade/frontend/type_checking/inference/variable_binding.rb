module Jade
  module Frontend
    module TypeChecking
      module Inference
        module VariableBinding
          extend Helpers
          extend self

          def infer(node, registry, env, var_gen, expected)
            node => AST::VariableBinding(name:, expression:)

            check(expression, registry, env, var_gen, expected)
              .then { it.with(env: it.env.bind(name, generalize(env, it.type))) }
          end
        end
      end
    end
  end
end


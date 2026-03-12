module Jade
  module Frontend
    module TypeChecking
      module Inference
        module VariableBinding
          extend Helpers
          extend self

          def infer(node, registry, state, expected)
            node => AST::VariableBinding(name:, expression:)

            new_state, new_result = check(expression, registry, state, expected)

            new_state
              .bind(name, generalize(state.env, new_result.type))
              .unify_result(new_result, expected.type)
          end
        end
      end
    end
  end
end


module Jade
  module Frontend
    module TypeChecking
      module Inference
        module RecordField
          extend Helpers
          extend self

          def infer(node, registry, env, var_gen, expected_type)
            node => AST::RecordField(value:)

            check(value, registry, env, var_gen, expected_type)
          end
        end
      end
    end
  end
end


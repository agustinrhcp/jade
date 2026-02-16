module Jade
  module Frontend
    module TypeChecking
      module Inference
        module RecordField
          extend Helpers
          extend self

          def infer(node, registry, env, expected_type)
            node => AST::RecordField(value:)

            check(value, registry, env, expected_type)
          end
        end
      end
    end
  end
end


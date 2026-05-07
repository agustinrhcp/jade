module Jade
  module Frontend
    module TypeChecking
      module Inference
        module RecordLiteral
          extend Helpers
          extend self

          def infer(node, registry, state, expected)
            node => AST::RecordLiteral(fields:)

            fields_state, fields_types = fields
              .reduce([state, {}]) do |(state_acc, types_acc), field|
                new_state, result = check(field, registry, state_acc, Expected.infer(state_acc.fresh))
                [new_state, types_acc.merge(field.key => result.type)]
              end

            [fields_state, Result.init(Type.anonymous_record(fields_types, nil))]
          end
        end
      end
    end
  end
end

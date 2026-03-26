module Jade
  module Frontend
    module TypeChecking
      module Inference
        module RecordUpdate
          extend Helpers
          extend self

          def infer(node, registry, state, expected)
            node => AST::RecordUpdate(base:, fields:)

            base_state, base_result = check(base, registry, state, Expected.infer(state.fresh))

            fields_state, fields_types = fields
              .reduce([base_state, {}]) do |(state_acc, types_acc), field|
                new_state, result = check(field, registry, state_acc, Expected.infer(state_acc.fresh))
                [new_state, types_acc.merge(field.key => result.type)]
              end

            update_record = Type.anonymous_record(fields_types, fields_state.fresh)

            after_state, result = fields_state.unify_result(base_result, update_record) do
              Error::RecordAccessTypeMismatch.new(
                state.env.entry_name,
                node.range,
                expected: it.expected,
                actual: it.actual,
              )
            end

            after_state.unify_result(result, expected.type)
          end
        end
      end
    end
  end
end

module Jade
  module Frontend
    module TypeChecking
      module Inference
        module RecordAccess
          extend Helpers
          extend self

          def infer(node, registry, state, expected_)
            node => AST::RecordAccess(target:, name:)

            record_expected = Type.anonymous_record(
              { name.name => expected_.type },
              state.fresh.with(name: 'a'),
            )

            target_state, target_result = check(target, registry, state, Expected.non_auth(state.fresh))
            after_state, _ = target_state.unify_result(target_result, record_expected) do
              Error::RecordAccessTypeMismatch.new(
                state.env.entry_name,
                name.range,
                expected: it.expected,
                actual: it.actual,
              )
            end

            Result.init(expected_.type)
              .then { it.apply(after_state.env.substitution) }
              .then { [after_state, it] }
          end
        end
      end
    end
  end
end

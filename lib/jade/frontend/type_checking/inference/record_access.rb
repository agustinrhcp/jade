module Jade
  module Frontend
    module TypeChecking
      module Inference
        module RecordAccess
          extend Helpers
          extend self

          def infer(node, registry, env, expected_)
            node => AST::RecordAccess(target:, name:)

            expected = Type
              .anonymous_record(
                { name.name => expected_.type },
                env.fresh.with(name: 'a'),
              )

            check(target, registry, env, Expected.non_auth(env.fresh))
              .and_unify(expected) do
                Error::RecordAccessTypeMismatch.new(
                  env.entry_name,
                  name.range,
                  expected: it.expected,
                  actual: it.actual,
                )
              end
              .then { it.with(type: (it.type || expected).fields[name.name]) }
          end
        end
      end
    end
  end
end

module Jade
  module Frontend
    module TypeChecking
      module Inference
        module RecordAccess
          extend Helpers
          extend self

          def infer(node, registry, env, var_gen, expected_)
            node => AST::RecordAccess(target:, name:)

            expected = Type
              .anonymous_record(
                { name.name => expected_.type },
                var_gen.fresh.with(name: 'a'),
              )

            check(target, registry, env, var_gen, Expected.non_auth(var_gen))
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

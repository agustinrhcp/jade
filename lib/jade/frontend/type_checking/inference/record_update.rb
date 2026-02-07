module Jade
  module Frontend
    module TypeChecking
      module Inference
        module RecordUpdate
          extend Helpers
          extend self

          def infer(node, registry, env, expected)
            node => AST::RecordUpdate(base:, fields:)

            check(base, registry, env, Expected.non_auth(env.fresh)) => {
              type: base_type, errors: base_errors,
            }

            fields
              .reduce(Result[{}, Substitution.new, env, []]) do |acc, field|
                check(field, registry, env, Expected.non_auth(env.fresh))
                  .compose_substitution(acc.substitution)
                  .add_errors(acc.errors)
                  .then { it.with(type: acc.type.merge(field.key => it.type)) }
              end
              .then { it.with(type: Type.anonymous_record(it.type, env.fresh)) }
              .add_errors(base_errors)
              .and_unify(base_type) do
                RecordAccessTypeMismatchError.new(node, it.actual, it.expected)
              end
              .and_unify(expected.type)
          end
        end
      end
    end
  end
end

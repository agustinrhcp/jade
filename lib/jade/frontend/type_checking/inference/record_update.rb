module Jade
  module Frontend
    module TypeChecking
      module Inference
        module RecordUpdate
          extend Helpers
          extend self

          def infer(node, registry, env, expected)
            node => AST::RecordUpdate(base:, fields:)

            base_r = check(base, registry, env, Expected.non_auth(env.fresh))

            fields
              .reduce(Result.init({}, env)) do |acc, field|
                check(field, registry, env, Expected.non_auth(env.fresh))
                  .then { acc.merge(it) }
                  .then { it.with(type: acc.type.merge(field.key => it.type)) }
              end
              .then { it.with(type: Type.anonymous_record(it.type, env.fresh)) }
              .then { base_r.merge(it) }
              .and_unify(base_r.type) do
                RecordAccessTypeMismatchError.new(node, it.actual, it.expected)
              end
              .and_unify(expected.type)
          end
        end
      end
    end
  end
end

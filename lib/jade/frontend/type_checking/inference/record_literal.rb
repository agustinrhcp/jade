module Jade
  module Frontend
    module TypeChecking
      module Inference
        module RecordLiteral
          extend Helpers
          extend self

          def infer(node, registry, env, expected)
            node => AST::RecordLiteral(fields:, symbol:)

            fields
              .reduce(Result.init({}, env)) do |acc, field|
                check(field, registry, env, Expected.non_auth(env.fresh))
                  .then { acc.merge(it) }
                  .then { it.with(type: acc.type.merge(field.key => it.type)) }
              end
              .then { it.with(type: Type.anonymous_record(it.type, nil)) }
          end
        end
      end
    end
  end
end

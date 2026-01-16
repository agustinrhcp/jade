module Jade
  module Frontend
    module TypeChecking
      module Inference
        module RecordAccess
          extend Helpers
          extend self

          def infer(node, registry, env, var_gen)
            node => AST::RecordAccess(target:, name:)

            expected = Type
              .anonymous_record(
                { name.name => Type.var(var_gen.fresh) },
                Type.var(var_gen.fresh),
              )

            check(target, registry, env, var_gen)
              .and_unify(expected) do
                RecordAccessTypeMismatchError.new(node, it.actual, it.expected)
              end
              .then { it.with(type: (it.type || expected).fields[name.name]) }
          end
        end
      end
    end
  end
end

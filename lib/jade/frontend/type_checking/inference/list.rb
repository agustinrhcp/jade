module Jade
  module Frontend
    module TypeChecking
      module Inference
        module List
          extend Helpers
          extend self

          def infer(node, registry, env, expected)
            node => AST::List(items:)

            if items.empty?
              return Result.new[
                Type.list.apply([expected.type]),
                Substitution.new,
                env,
                []
              ]
            end

            head, *rest = items
            head_result = check(head, registry, env, Expected.non_auth(env.fresh))

            rest
              .each_with_index
              .reduce(head_result) do |acc, (item, i)|
                check(item, registry, acc.env, Expected.non_auth(env.fresh))
                  .compose_substitution(acc.substitution)
                  .add_errors(acc.errors)
                  .and_unify(acc.type) do
                    Error::ListItemTypeMismatch.new(
                      env.entry_name,
                      item.range,
                      expected: it.expected,
                      actual: it.actual,
                      actual_index: i + 2,
                    )
                  end
              end
              .then { it.with(type: Type.list.apply([it.type])) }
              .and_unify(expected.type)
          end
        end
      end
    end
  end
end

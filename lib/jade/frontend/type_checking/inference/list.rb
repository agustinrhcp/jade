module Jade
  module Frontend
    module TypeChecking
      module Inference
        module List
          extend Helpers
          extend self

          def infer(node, registry, env, var_gen)
            node => AST::List(items:)

            if items.empty?
              return Result.new[
                Type.list.apply([Type.var(var_gen.fresh)]),
                Substitution.new,
                env,
                []
              ]
            end

            head, *rest = items
              .map do |item|
                check(item, registry, env, var_gen)
              end

            rest
              .each_with_index.reduce(head) do |acc, (item, i)|
                acc
                  .compose_substitution(item.substitution)
                  .add_errors(item.errors)
                  .and_unify(item.type) do
                    ListItemTypeMismatchError.new(node, it.actual, it.expected, i + 2)
                  end
              end
              .then { it.with(type: Type.list.apply([it.type])) }
          end
        end
      end
    end
  end
end

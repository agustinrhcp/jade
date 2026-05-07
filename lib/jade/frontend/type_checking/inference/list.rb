module Jade
  module Frontend
    module TypeChecking
      module Inference
        module List
          extend Helpers
          extend self

          def infer(node, registry, state, expected)
            node => AST::List(items:)

            if items.empty?
              Type.list.apply([state.fresh])
                .then { Result.init(it) }
                .then { return state.unify_result(it, expected.type, expected.rigid_vars) }
            end

            head, *rest = items
            head_state, head_result = check(head, registry, state, Expected.infer(state.fresh))

            items_state, items_result = rest
              .each_with_index
              .reduce([head_state, head_result]) do |(state_acc, result_acc), (item, i)|
                new_state, result = check(item, registry, state_acc, Expected.infer(state_acc.fresh))
                new_state
                  .unify_result(result, result_acc.type, &type_error(new_state, item, i))
                  .then { |st, rs| [st, rs.with(constraints: result_acc.constraints + rs.constraints)] }
              end

            Result
              .init(Type.list.apply([items_result.type]), items_result.constraints)
              .then { items_state.unify_result(it, expected.type, expected.rigid_vars) }
          end

          private

          def type_error(state, item, index)
            ->(error) do
              Error::ListItemTypeMismatch.new(
                state.env.entry_name,
                item.range,
                expected: error.expected,
                actual: error.actual,
                actual_index: index + 2,
              )
            end
          end
        end
      end
    end
  end
end

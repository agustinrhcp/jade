module Jade
  module Frontend
    module TypeChecking
      module Inference
        module FunctionCall
          extend Helpers
          extend self

          def infer(node, registry, state, expected)
            node => AST::FunctionCall(callee:, args:)

            callee_state, callee_result = check(callee, registry, state, Expected.infer(state.fresh))
              .then { |st, rs| [st, rs.attach_origin(node)] }

            args_state, args_acc = args
              .reduce([callee_state, Result.accumulator]) do |(state_acc, acc), arg|
                new_state, result = check(arg, registry, state_acc, Expected.infer(state_acc.fresh))
                [new_state, acc.add(result)]
              end

            return_type = args_state.fresh
            fn_type = Type.function(args_acc.types, return_type)

            after_callee_state, _fn_result = args_state.unify_result(
              Result.init(fn_type),
              callee_result.type,
              &type_error(state, node)
            )

            after_callee_state.unify_result(
              callee_result.map(&:return_type),
              expected.type,
              &type_error(state, node)
            )
            .then do |st, rs|
              # TODO: This is only for concrete constraints.
              rs
                .constraints
                .flat_map { Constraints.solve_at_call_site(it, registry, st.env.entry_name) }
                .then { st.add_errors(it) }
                .then { [it, rs] }
            end
          end

          private

          def type_error(state, node)
            ->(e) do
              Error::FunctionCallTypeMismatch.new(
                state.env.entry_name,
                node.range,
                expected: e.expected,
                actual: e.actual,
                infix: node.infix,
              )
            end
          end
        end
      end
    end
  end
end

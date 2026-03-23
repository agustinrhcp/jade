module Jade
  module Frontend
    module TypeChecking
      module Inference
        module FunctionCall
          extend Helpers
          extend self

          def infer(node, registry, state, expected)
            node => AST::FunctionCall(callee:, args:)

            callee_state, callee_result =
              check(callee, registry, state, Expected.non_auth(state.fresh))
                .then { |st, rs| [st, rs.attach_origin(node)] }

            args_state, args_acc = args
              .reduce([callee_state, Result.accumulator]) do |(state_acc, acc), arg|
                new_state, result = check(arg, registry, state_acc, Expected.non_auth(state_acc.fresh))
                [new_state, acc.add(result)]
              end

            return_type = args_state.fresh
            fn_type = Type.function(args_acc.types, return_type)

            after_callee_state, _fn_result = args_state.unify_result(
              Result.init(fn_type),
              callee_result.type,
              &type_error(state, node)
            )

            after_callee_state
              .unify_result(
                callee_result.map(&:return_type),
                expected.type,
                &type_error(state, node)
              )
              .then do |st, rs|
                # TODO: This is only for concrete constraints.
                [
                  st.add_errors(solve_constraints(rs.constraints, registry, st.env)),
                  rs,
                ]
              end
          end

          private

          def add_dictionaries_to_node(node)
            ->((_, result)) do
              result
                .constraints
                # mutates the node
                .then { node.dictionaries.concat(it) }
            end
          end

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

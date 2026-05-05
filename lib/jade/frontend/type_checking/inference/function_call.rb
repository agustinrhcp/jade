module Jade
  module Frontend
    module TypeChecking
      module Inference
        module FunctionCall
          extend Helpers
          extend self

          def infer(node, registry, state, expected)
            node => AST::FunctionCall(callee:, args:)

            callee_state, callee_result = check(
              callee,
              registry,
              state,
              Expected.infer(state.fresh),
            )
              .then { |st, rs| [st, rs.attach_origin(node)] }

            args_state, args_acc = args
              .reduce([callee_state, Result.accumulator]) do |(state_acc, acc), arg|
                check(
                  arg,
                  registry,
                  state_acc,
                  Expected.infer(state_acc.fresh),
                )
                .then { |(new_state, result)| [new_state, acc.add(result)] }
              end

            after_callee_state, result_type = unify_callee(
              args_state,
              callee_result,
              args_acc,
              node,
              state,
            )

            after_callee_state.unify_result(
              callee_result.map { result_type },
              expected.type,
              &type_error(state, node)
            )
            .then do |st, rs|
              # dictionaries is a mutable array in the function call node,
              # if we don't skipt constraints on the first pass, we end up adding
              # double dispatch code.
              next [st, rs] if st.skip_constraints

              (rs.constraints + args_acc.constraints)
                .map { st.env.substitution.apply(it) }
                .partition { it.type.is_a?(Type::Var) }
                .then { |propagated, solvable|
                  solvable
                    .flat_map { Constraints.solve_at_call_site(it, registry, st.env.entry_name) }
                    .then { [st.add_errors(it), rs.with(constraints: propagated)] }
                }
            end
          end

          private

          # `f` for `def f() -> T` has type `T` directly,
          # so `f()` is a no-op and yields `T`. Skip the Function(args, ret)
          # unification in that case to avoid spurious type errors.
          def unify_callee(state, callee_result, args_acc, node, outer)
            case [args_acc.types, state.env.substitution.apply(callee_result.type)]
            in [[], Type::Function => applied]
              unify_as_function(state, callee_result, args_acc, node, outer)

            in [[], applied]
              [state, applied]

            else
              unify_as_function(state, callee_result, args_acc, node, outer)
            end
          end

          def unify_as_function(state, callee_result, args_acc, node, outer)
            return_type = state.fresh
            fn_type = Type.function(args_acc.types, return_type)

            state
              .unify_result(Result.init(fn_type), callee_result.type, &type_error(outer, node))
              .first
              .then { [it, return_type] }
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

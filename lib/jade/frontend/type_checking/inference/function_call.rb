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
              # When expected is authoritative and this unification failed,
              # adopt expected.type so the enclosing body-level unify doesn't
              # re-report the same mismatch.
              adopted = expected.check? && st.errors.size > after_callee_state.errors.size
              base_rs = adopted ? rs.with(type: expected.type) : rs

              callee_subst = base_rs
                .constraints
                .map { st.env.substitution.apply(it) }

              args_subst = args_acc
                .constraints
                .map { st.env.substitution.apply(it) }

              propagated = (callee_subst + args_subst)
                .select { it.type.is_a?(Type::Var) }

              # Pass 1 still needs propagation so constraints from inner calls
              # bubble up through outer constructor calls and reach the function
              # binding before generalization. Skip only the mutating dictionary
              # attachment, which would otherwise emit double dispatch code.
              next [st, base_rs.with(constraints: propagated)] if st.skip_constraints

              # Attach a resolution per callee constraint, in callee order, so codegen
              # can pass dicts positionally. Concrete constraints attach a resolved
              # Implementation; var-typed ones attach themselves as a marker meaning
              # "use the enclosing function's local dict".
              callee_errors = callee_subst
                .flat_map do |c|
                  case c.type
                  in Type::Var
                    Constraints.attach_dictionary(c, c)
                    []
                  else
                    Constraints.solve_at_call_site(c, registry, st.env.entry_name)
                  end
                end

              # Args' constraints dispatch at their own origins (inner call sites).
              args_errors = args_subst
                .reject { it.type.is_a?(Type::Var) }
                .flat_map { Constraints.solve_at_call_site(it, registry, st.env.entry_name) }

              st
                .add_errors(callee_errors + args_errors)
                .then { [it, base_rs.with(constraints: propagated)] }
            end
          end

          private

          def unify_callee(state, callee_result, args_acc, node, outer)
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

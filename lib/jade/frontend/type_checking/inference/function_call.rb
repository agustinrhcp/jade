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

            args_state = args_state.add_errors(Division.by_zero(node, args_state.env.entry_name))

            after_callee_state, result_type = unify_callee(
              args_state,
              callee_result,
              Division.lift(node, args_acc),
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
                .flat_map { propagate(it, registry, st.env.entry_name) }

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
                  case c
                  in Type::Constraint(index: :unindex) then []

                  in Type::Constraint(type: Type::Var)
                    Constraints.attach_dictionary(c, c)
                    []

                  else
                    Constraints.solve_at_call_site(c, registry, st.env.entry_name)
                  end
                end

              # Args' constraints dispatch at their own origins (inner call sites,
              # or a QualifiedAccess/VariableReference when a polymorphic fn is
              # passed as a value). Var-typed ones attach themselves as a marker,
              # mirroring the callee path, so reference-as-value codegen can
              # resolve via the enclosing function's dict_env.
              args_errors = args_subst
                .flat_map do |c|
                  case c
                  in Type::Constraint(index: :unindex) then []

                  in Type::Constraint(type: Type::Var)
                    Constraints.attach_dictionary(c, c)
                    []

                  else
                    Constraints.solve_at_call_site(c, registry, st.env.entry_name)
                  end
                end

              column_errors = Extensions.check_call(
                callee_name(callee),
                args_acc.types.map { st.env.substitution.apply(it) },
                st.env.substitution.apply(result_type),
                node,
                registry,
                st.env.entry_name,
                node.range,
              )

              st
                .add_errors(callee_errors + args_errors + column_errors)
                .then { [it, base_rs.with(constraints: propagated)] }
            end
          end

          private

          # Only bare-var constraints earn a dict param, so a constraint that
          # still holds free vars (`Decodable(List(a))`) surfaces its deps as
          # markers of their own — unindexed, since they occupy no slot in
          # this call's dictionary list.
          # A call through a local binding or a lambda has no name to give a
          # check, which asks by qualified name.
          def callee_name(callee)
            case callee
            in AST::VariableReference(symbol: Symbol::Variable) then nil
            in AST::VariableReference(symbol:) then symbol.qualified_name
            in AST::QualifiedAccess(symbol:) then symbol.qualified_name
            else nil
            end
          end

          def propagate(constraint, registry, entry_name)
            return [constraint] if constraint.type.is_a?(Type::Var)
            return [] if constraint.unbound_vars.empty?

            Constraints
              .resolve(constraint, registry, entry_name)
              .map { var_markers(it) }
              .with_default([])
          end

          def var_markers(dep)
            case dep
            in Symbol::Implementation(deps:) then deps.flat_map { var_markers(it) }
            in Type::Constraint(type: Type::Var) then [dep.with(origin: nil, index: :unindex)]
            else []
            end
          end

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
                lifted_placeholder: lifted_placeholder?(node),
                callee_name: source_name(node.callee),
                arg_names: node.args.map { source_name(it) },
              )
            end
          end

          # Desugaring lifted the `_` into a lambda parameter, so a hole
          # reads as an argument referring to one by the time we get here.
          def lifted_placeholder?(node)
            node.args.any? { it in AST::VariableReference(name: /\A__p\d+__\z/) }
          end

          # What the author called this, where they called it something.
          def source_name(node)
            case node
            in AST::ConstructorReference | AST::VariableReference
              node.name

            in AST::QualifiedAccess(path:)
              path.join('.')

            else
              nil
            end
          end
        end
      end
    end
  end
end

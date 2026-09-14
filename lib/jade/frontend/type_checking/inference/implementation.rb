module Jade
  module Frontend
    module TypeChecking
      module Inference
        module Implementation
          extend Helpers
          extend self

          def infer(node, registry, state, _expected)
            node => AST::Implementation(functions:)

            impl = node.symbol

            interface_sym   = registry.lookup(impl.interface)
            interface_qname = impl.interface.qualified_name

            # Build the concrete type for the constructor, respecting its type params
            concrete_type, = type_from_symbol(impl.type, registry, state.env.var_gen)

            functions
              .reduce(state) do |st, impl_fn|
                impl_fn => AST::ImplementationFunction(name:)

                iface_fn = interface_sym
                  .functions
                  .find { |f| f.name == name }

                # Instantiate the interface function with fresh vars
                iface_fn_type, iface_fn_constraints =
                  type_from_symbol(iface_fn, registry, st.env.var_gen)

                # The type var standing for the interface's type param
                t_var = iface_fn_constraints
                  .find { |c| c.interface == interface_qname }
                  .type

                # When the interface uses t_var as a constructor (e.g. f(a) -> f(b)),
                # bind it to a partial application so that f(a) beta-reduces correctly.
                # For 1-param types (Maybe): tail = [] → constructor
                # For 2-param types (Result): tail = [e] → PartialApplication[Constructor, [e]]
                binding_type =
                  case [constructor_var_in?(iface_fn_type, t_var.id), concrete_type]
                  in [true, Type::Application(constructor:, args:)]
                    tail = args.drop(1)
                    tail.empty? ? constructor : Type::PartialApplication[constructor, tail]
                  else
                    concrete_type
                  end

                # Bind the interface type var to the concrete type
                st_after_bind = st.unify(t_var, binding_type) { nil }
                expected_type = st_after_bind.env.substitution.apply(iface_fn_type)

                infer_fn(
                  impl_fn,
                  registry,
                  st_after_bind,
                  Expected.check(expected_type),
                  interface_qname,
                  concrete_type,
                )
              end
              .then { [it, Result.init(Type.unit)] }
          end

          private

          def infer_fn(impl_fn, registry, state, expected, interface_qname, head_type)
            impl_fn => AST::ImplementationFunction(name:, fn:)

            case fn
            in AST::Lambda(params: [])
              # 0-arg lambda for a non-function field (e.g. `decoder: () -> { ... }`
              # against `decoder: Decoder(a)`) acts as a thunk: type the body and
              # unify with expected. Mirrors `from_symbol_r`'s 0-arg collapse for
              # named `def f() -> T`. Codegen emits a `->()` either way; the
              # runtime always `.call`s the impl entry.
              if expected.type.is_a?(Type::Function)
                check(fn, registry, state, expected).first
              else
                body_state, body_result = check(
                  fn.body,
                  registry,
                  state,
                  Expected.infer(state.fresh),
                )
                body_state
                  .unify(
                    body_result.type,
                    expected.type,
                    &mismatch_error(state.env.entry_name, impl_fn, interface_qname, name)
                  )
                  .then do |unified|
                    unified.add_errors(
                      foreign_constraints(
                        body_result.constraints,
                        head_type,
                        unified,
                        impl_fn,
                        interface_qname,
                        name,
                      ),
                    )
                  end
              end

            in AST::Lambda
              lambda_state, lambda_result = check(fn, registry, state, expected)

              lambda_state.add_errors(
                foreign_constraints(
                  lambda_result.constraints,
                  head_type,
                  lambda_state,
                  impl_fn,
                  interface_qname,
                  name,
                ),
              )

            in AST::VariableReference
              ref_state, ref_result = check(fn, registry, state, expected)

              ref_state
                .unify(
                  ref_result.type,
                  expected.type,
                  &mismatch_error(
                    state.env.entry_name,
                    impl_fn,
                    interface_qname,
                    name
                  )
                )
                .then do |unified|
                  unified.add_errors(
                    foreign_constraints(
                      ref_result.constraints,
                      head_type,
                      unified,
                      impl_fn,
                      interface_qname,
                      name,
                    ),
                  )
                end

            # `decoder: zero_arg_fn` becomes `FunctionCall(zero_arg_fn, [])`
            # after ZeroArgRewrite. Type the call; its result must match the
            # interface field's type.
            in AST::FunctionCall
              check(fn, registry, state, expected).first
            end
          end

          def foreign_constraints(constraints, head_type, state, impl_fn, interface_qname, fn_name)
            substitution = state.env.substitution
            head_vars = substitution.apply(head_type).unbound_vars.map(&:id).to_set

            constraints
              .map { substitution.apply(it) }
              .reject { it.unbound_vars.all? { |v| head_vars.include?(v.id) } }
              .map do
                Error::ImplementationFunctionConstraint.new(
                  state.env.entry_name,
                  impl_fn.range,
                  interface: interface_qname,
                  fn_name:,
                  constraint: it.to_s,
                )
              end
          end

          def constructor_var_in?(type, var_id)
            case type
            in Type::Application(constructor: Type::Var(id:)) if id == var_id
              true

            in Type::Application(constructor:, args:)
              [constructor, *args].any? { constructor_var_in?(it, var_id) }

            in Type::Function(args:, return_type:)
              [*args, return_type].any? { constructor_var_in?(it, var_id) }

            else
              false
            end
          end

          def mismatch_error(entry_name, impl_fn, interface_qname, fn_name)
            ->(e) do
              Error::ImplementationTypeMismatch.new(
                entry_name,
                impl_fn.range,
                expected: e.expected,
                actual:   e.actual,
                interface: interface_qname,
                fn_name:,
              )
            end
          end
        end
      end
    end
  end
end

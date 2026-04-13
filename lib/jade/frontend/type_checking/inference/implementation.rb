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

            # TODO: This is not the only place we registry things!
            # Register so constraint solving can find this implementation
            registry
              .implementations
              .merge!(
                [impl.interface.qualified_name, impl.type.qualified_name] => impl
              )

            interface_sym   = registry.lookup(impl.interface)
            interface_qname = impl.interface.qualified_name

            # Build the concrete type for the constructor, respecting its type params
            concrete_type, = type_from_symbol(impl.type, registry, state.env.var_gen)

            functions
              .reduce(state) do |st, impl_fn|
                impl_fn => AST::ImplementationFunction(name:, fn: fn_name)

                iface_fn = interface_sym
                  .functions
                  .find { |f| f.name == name }
                # next st unless iface_fn

                # Instantiate the interface function with fresh vars
                iface_fn_type, iface_fn_constraints =
                  type_from_symbol(iface_fn, registry, st.env.var_gen)

                # The type var standing for the interface's type param
                t_var = iface_fn_constraints
                  .find { |c| c.interface == interface_qname }
                  .type

                # Bind the interface type var to the concrete type
                st_after_bind = st.unify(t_var, concrete_type) { nil }
                expected_type = st_after_bind.env.substitution.apply(iface_fn_type)

                # Look up the declared function's type
                fn_qname = "#{st.env.entry_name}.#{fn_name}"
                st_after_bind.env.lookup(fn_qname) => { type: declared_type }

              st_after_bind.unify(declared_type, expected_type) do |e|
                Error::ImplementationTypeMismatch.new(
                  st.env.entry_name,
                  node.range,
                  expected: e.expected,
                  actual:   e.actual,
                  interface: interface_qname,
                  fn_name:   name,
                )
              end
            end
            .then { [it, Result.init(Type.unit)] }
          end
        end
      end
    end
  end
end

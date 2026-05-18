module Jade
  module Frontend
    module TypeChecking
      module Inference
        module FunctionDeclaration
          extend Helpers
          extend self

          def infer(node, registry, state, _)
            node => AST::FunctionDeclaration(symbol:, body:, params:)

            # Use the binding directly instead of env.lookup, which would
            # instantiate fresh vars and detach body call sites' dict markers
            # from the binding's stored constraints.
            state
              .env
              .bindings[symbol.qualified_name] => {
                type: fn_type, constraints: fn_constraints,
              }

            arg_types, return_type = Type.signature(fn_type)

            new_state, body_result = arg_types
              .zip(params)
              .reduce(state) do |acc, (t, p)|
                acc.bind(p.name, Scheme.mono(t))
              end
              .then { check(body, registry, it, Expected.check(return_type)) }

            new_state
              .unify(
                body_result.type,
                return_type,
                fn_type.unbound_vars
              ) do
                Error::FunctionBodyTypeMismatch.new(
                  state.env.entry_name,
                  node.range,
                  expected: it.expected,
                  actual: it.actual,
                  function_name: node.name,
                )
              end
              .then do |st|
                next st if st.env.bindings[symbol.qualified_name].is_a?(Scheme)

                updated_constraints = (fn_constraints + body_result.constraints)
                  .map { st.env.substitution.apply(it) }
                  .uniq

                # TODO: for impl function declarations, unresolved constraints here
                # (e.g. Eq(a) when the body calls == on a field of type a) should
                # be stored as impl-level constraints, not function-level ones.
                # The impl finalization pass (see TypeChecking.finalize) should then
                # promote them into deps when the impl is instantiated for a concrete type.
                st.bind(
                  symbol.qualified_name,
                  Placeholder[
                    st.env.substitution.apply(fn_type),
                    updated_constraints,
                  ]
                )
              end
              .then { [it, Result.init(Type.unit)] }
          end
        end
      end
    end
  end
end

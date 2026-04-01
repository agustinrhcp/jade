module Jade
  module Frontend
    module TypeChecking
      module Inference
        module FunctionDeclaration
          extend Helpers
          extend self

          def infer(node, registry, state, _)
            node => AST::FunctionDeclaration(symbol:, body:, params:)

            state.env.lookup(symbol.qualified_name) => { type: fn_type, constraints: fn_constraints }

            new_state, body_result = fn_type
              .args
              .zip(params)
              .reduce(state) do |acc, (t, p)|
                acc.bind(p.name, Scheme.mono(t))
              end
              .then { check(body, registry, it, Expected.check(fn_type.return_type)) }

            new_state
              .unify(
                body_result.type,
                fn_type.return_type,
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

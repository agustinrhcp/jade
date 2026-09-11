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
            declared = !registry.lookup(symbol).return_type.is_a?(Symbol::Inferred)
            expected = declared ? Expected.check(return_type) : Expected.infer(return_type)

            new_state, body_result = arg_types
              .zip(params)
              .reduce(state) do |acc, (t, p)|
                acc.bind(p.name, Scheme.mono(t))
              end
              .then { check(body, registry, it, expected) }

            new_state
              .unify(
                body_result.type,
                return_type,
                declared ? fn_type.unbound_vars : []
              ) do
                Error::FunctionBodyTypeMismatch.new(
                  state.env.entry_name,
                  node.range,
                  expected: it.expected,
                  actual: it.actual,
                  function_name: node.name,
                )
              end
              .then { |st| report_narrowing(st, node, symbol, registry, fn_type) }
              .then do |st|
                next st if st.env.bindings[symbol.qualified_name].is_a?(Scheme) && !st.skip_constraints

                updated_constraints = (fn_constraints + body_result.constraints)
                  .map { st.env.substitution.apply(it) }
                  .uniq { it.type.is_a?(Type::Var) ? [it.interface, it.type] : it }

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

          private

          def report_narrowing(state, node, symbol, registry, fn_type)
            Type
              .from_symbol(registry.lookup(symbol), registry, state.env.var_gen)
              .first
              .then { Narrowing.against_declaration(it, state.env.substitution.apply(fn_type)) }
              .then { it ? state.add_errors([narrowed(it, state, node)]) : state }
          end

          def narrowed((var, found), state, node)
            Error::NarrowedSignature.new(
              state.env.entry_name,
              node.range,
              function_name: node.name,
              var: var.name,
              found:,
            )
          end
        end
      end
    end
  end
end

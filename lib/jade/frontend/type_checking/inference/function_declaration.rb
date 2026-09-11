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
              .then { |st| keep_signature(st, node, symbol, registry, fn_type) }
              .then do |st|
                next st if st.env.bindings[symbol.qualified_name].is_a?(Scheme) && !st.skip_constraints

                updated_constraints = (fn_constraints + body_result.constraints)
                  .map { st.env.substitution.apply(it) }
                  .uniq { it.type.is_a?(Type::Var) ? [it.interface, it.type] : it }

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

          private

          def keep_signature(state, node, symbol, registry, fn_type)
            Type
              .from_symbol(registry.lookup(symbol), registry, state.env.var_gen)
              .first
              .then { narrowing(it, state.env.substitution.apply(fn_type)) }
              .then { it ? state.add_errors([narrowed(it, state, node)]) : state }
          end

          def narrowing(declared, actual)
            pairs(declared, actual).then do |found|
              found.find { |(_, type)| !type.is_a?(Type::Var) } ||
                found
                  .uniq { |(var, _)| var.id }
                  .group_by { |(_, type)| type.id }
                  .values
                  .find { it.size > 1 }
                  &.then { |((var, _), (other, _))| [var, other] }
            end
          end

          def pairs(declared, actual)
            case declared
            in Type::Var
              [[declared, actual]]

            in Type::Application(constructor:, args:)
              pairs(constructor, actual.constructor) + zipped(args, actual.args)

            in Type::Function(args:, return_type:)
              zipped(args, actual.args) + pairs(return_type, actual.return_type)

            in Type::AnonymousRecord(fields:, row_var:)
              fields.flat_map { |name, type| pairs(type, actual.fields.fetch(name)) } +
                row_pairs(row_var, fields, actual)

            else
              []
            end
          end

          def zipped(declared, actual)
            declared
              .zip(actual)
              .flat_map { |(d, a)| pairs(d, a) }
          end

          def row_pairs(row_var, fields, actual)
            return [] unless row_var

            (actual.fields.keys - fields.keys).empty? && actual.row_var ?
              pairs(row_var, actual.row_var) :
              [[row_var, actual]]
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

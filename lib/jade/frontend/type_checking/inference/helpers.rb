module Jade
  module Frontend
    module TypeChecking
      module Inference
        module Helpers
          extend self

          def unify(actual, expected)
            Unification.unify(actual, expected)
          end

          def instantiate(scheme, var_gen)
            Instantiation.instantiate(scheme, var_gen)
          end

          def generalize(type)
            Generalization.generalize(type)
          end

          def type_from_symbol(symbol, registry)
            case symbol
            in Symbol::Variable(name:)
              Type.var(name)

            in Symbol::TypeRef | Symbol::ValueRef
              registry
                .lookup(symbol)
                .then { type_from_symbol(it, registry) }

            in Symbol::Union
              Type
                .constructor(symbol.qualified_name)
                .apply(symbol.type_params.map { type_from_symbol(it, registry) })

            in Symbol::Function | Symbol::StdlibFunction
              Type
                .function(
                  symbol.params.values.map { type_from_symbol(it, registry) },
                  type_from_symbol(symbol.return_type, registry)
                )

            in Symbol::FunctionType
              Type
                .function(
                  symbol.params.map { type_from_symbol(it, registry) },
                  type_from_symbol(symbol.return_type, registry)
                )

            in Symbol::Variant
              Type
                .function(
                  symbol.args.map { type_from_symbol(it, registry) },
                  type_from_symbol(symbol.union, registry)
                )
            end
          end

          def check(node, registry, env, var_gen)
            TypeChecking.check_node(node, registry, env, var_gen)
          end
        end
      end
    end
  end
end

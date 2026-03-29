module Jade
  module Frontend
    module TypeChecking

      StructDef = Data.define(:name, :type_params, :body)
      TypeDef = Data.define(:name, :type_params, :constructors)
      ConstructorDef = Data.define(:name, :parent_name, :args)
      InterfaceDef = Data.define(:name)

      module Definition
        extend self

        def from_symbol(sym, var_gen = VarGen.new, registry)
          # TODO: Don't need a var gen here, definitions don't have identity. they just share the name
          case sym
          in Symbol::Struct
            type_params, type_params_map = sym
              .type_params
              .reduce([[], {}]) do |(types, local_map), sym|
                Type.send(:from_symbol_r, sym, registry, var_gen, local_map)
                  .then { |(t, new_map)| [types + [t], new_map] }
              end

            Type
              .send(:from_symbol_r, sym.record_type, registry, var_gen, type_params_map)
              .first
              .then { Definition.struct(sym.qualified_name, type_params, it) }

          in Symbol::Union
            type = Type.from_symbol(sym, registry, var_gen).first

            sym
              .variants
              .map do |variant|
                Type
                  .from_symbol(variant, registry, var_gen)
                  .first
                  .then { Definition.constructor(variant.qualified_name, sym.qualified_name, it.args) }
              end
              .then { Definition.type(sym.qualified_name, type.args, it) }

          in Symbol::Interface(name:)
            InterfaceDef[name]

          in Symbol::TypeRef
            registry
              .lookup(sym)
              .then { from_symbol(it, var_gen, registry) }
          end
        end

        def constructor(name, parent_name, args)
          ConstructorDef[name, parent_name, args]
        end

        def type(name, type_params, constructors)
          TypeDef[name, type_params, constructors]
        end

        def struct(name, type_params, body)
          StructDef[name, type_params, body]
        end
      end
    end
  end
end

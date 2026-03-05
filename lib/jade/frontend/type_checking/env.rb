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
            type = Type.from_symbol(sym, registry, var_gen)

            sym
              .variants
              .map do |variant|
                Type
                  .from_symbol(variant, registry, var_gen)
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

      Env = Data.define(:entry_name, :bindings, :definitions, :implementations, :var_gen) do
        def self.empty(var_gen = VarGen.new)
          Env[nil, {}, {}, {}, var_gen]
        end

        def fresh
          var_gen.fresh
        end

        def self.load(entry, registry)
          empty
            .with(entry_name: entry.name)
            .load_bindings(entry, registry)
            .load_definitions(entry, registry)
            .with(implementations: registry.implementations)
        end

        def bind(key, value)
          bindings
            .merge(key => value)
            .then { with(bindings: it) }
        end

        def define(key, value)
          definitions
            .merge(key => value)
            .then { with(definitions: it) }
        end

        def lookup(key)
          bindings[key]
        end

        def lookup_def(key)
          definitions[key]
        end

        def free_vars
          bindings.values.flat_map(&:free_vars).to_set.to_a
        end

        def load_bindings(entry, registry)
          entry
            .values
            .reduce(self) do |env, (unq, sym)|
              Type.from_symbol(sym, registry, env.var_gen)
                .then { Inference::Helpers.generalize(env, it) }
                .then { env.bind(sym.qualified_name, it) }
            end
        end

        def load_definitions(entry, registry)
          entry
            .types
            .reduce(self) do |env, (_, sym)|
              Definition.from_symbol(sym, registry)
                .then { env.define(sym.qualified_name, it) }
            end
        end
      end
    end
  end
end

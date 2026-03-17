module Jade
  module Frontend
    module TypeChecking

      Env = Data.define(:entry_name, :bindings, :substitution, :definitions, :var_gen) do
        def self.empty(var_gen = VarGen.new)
          Env[nil, {}, Substitution.new, {}, var_gen]
        end

        def fresh
          var_gen.fresh
        end

        def self.load(entry, registry)
          empty
            .with(entry_name: entry.name)
            .load_bindings(entry, registry)
            .load_definitions(entry, registry)
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
          type, constraints = Instantiation.instantiate(bindings[key], var_gen)

          Result.init(
            substitution.apply(type),
            constraints.map { it.with(type: substitution.apply(it.type)) },
          )
        end

        def lookup_def(key)
          definitions[key]
        end

        def free_vars
          bindings.values.flat_map(&:free_vars).to_set.to_a
        end

        def composose_substitution(sub)
          with(substitution: substitution.compose(sub))
        end

        def load_bindings(entry, registry)
          load_local_bindings(entry, registry)
            .load_imported_bindings(entry, registry)
        end

        def load_local_bindings(entry, registry)
          entry.defined_values.reduce(self) do |env, (_, sym)|
            Type
              .from_symbol(sym, registry, env.var_gen)
              .then { Inference::Helpers.generalize(env, it) }
              .then { env.bind(sym.qualified_name, it) }
          end
        end

        def load_imported_bindings(entry, registry)
          entry.imports.reduce(self) do |env, import_entry|
            import_entry.qualified_symbols
              .select { it.is_a?(Symbol::ValueRef) }
              .reduce(env) do |env, sym|
                next env if env.bindings[sym.qualified_name]
                registry
                  .get(sym.module_name)
                  .env
                  .bindings[sym.qualified_name]
                  .then { env.bind(sym.qualified_name, it) }
              end
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

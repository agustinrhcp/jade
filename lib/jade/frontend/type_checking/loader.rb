module Jade
  module Frontend
    module TypeChecking
      module Loader
        extend self

        def load(entry, registry, env: Env.empty)
          env
            .with(entry_name: entry.name)
            .then { load_bindings(it, entry, registry) }
            .then { load_definitions(it, entry, registry) }
        end

        def load_bindings(env, entry, registry)
          load_local_bindings(env, entry, registry)
            .then { load_imported_bindings(it, entry, registry) }
        end

        def load_local_bindings(env, entry, registry)
          entry.defined_values.reduce(env) do |e, (_, sym)|
            case sym
            in Symbol::Function
              Type
                .from_symbol(sym, registry, e.var_gen)
                .then { Placeholder[*it] }

            else
              Type
                .from_symbol(sym, registry, e.var_gen)
                .then { Inference::Helpers.generalize(e, *it) }
            end
              .then { e.bind(sym.qualified_name, it) }
          end
        end

        def load_imported_bindings(env, entry, registry)
          entry.imports.reduce(env) do |e, import_entry|
            import_entry
              .qualified_symbols
              .select { it.is_a?(Symbol::ValueRef) }
              .reduce(e) do |e2, sym|
                next e2 if e2.bindings[sym.qualified_name]

                registry
                  .get(sym.module_name)
                  .env
                  .bindings[sym.qualified_name]
                  .then { e2.bind(sym.qualified_name, it) }
              end
          end
        end

        def load_definitions(env, entry, registry)
          entry
            .types
            .reduce(env) do |e, (_, sym)|
              Definition.from_symbol(sym, registry)
                .then { e.define(sym.qualified_name, it) }
            end
        end
      end
    end
  end
end

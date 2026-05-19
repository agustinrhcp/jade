module Jade
  module Frontend
    module TypeChecking
      module Loader
        extend self

        def load(entry, registry, env: Env.empty)
          env
            .with(entry_name: entry.name)
            .then { load_local_bindings(it, entry, registry) }
            .then { load_local_definitions(it, entry, registry) }
            .then { load_imports(it, entry, registry) }
        end

        def load_local_bindings(env, entry, registry)
          entry
            .defined_values
            .reduce(env) do |e, (_, sym)|
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

        def load_local_definitions(env, entry, registry)
          entry
            .types
            .reduce(env) do |e, (_, sym)|
              Definition
                .from_symbol(sym, registry)
                .then { e.define(sym.qualified_name, it) }
            end
        end

        def load_imports(env, entry, registry)
          entry
            .imports
            .reduce(env) do |e, import_entry|
              import_entry.qualified_symbols.reduce(e) do |acc, sym|
                add_imported_symbol(acc, sym, registry)
              end
            end
        end

        def add_imported_symbol(env, sym, registry)
          case sym
          in Symbol::ValueRef
            return env if env.bindings[sym.qualified_name]

            upstream_env = registry.get(sym.module_name)&.env
            return env unless upstream_env

            upstream_env
              .bindings[sym.qualified_name]
              &.then { env.bind(sym.qualified_name, it) } || env

          in Symbol::TypeRef
            return env if env.lookup_def(sym.qualified_name)

            Definition
              .from_symbol(sym, registry)
              .then { env.define(sym.qualified_name, it) }

          else
            env
          end
        end
      end
    end
  end
end

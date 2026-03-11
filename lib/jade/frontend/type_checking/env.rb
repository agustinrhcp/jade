module Jade
  module Frontend
    module TypeChecking

      Env = Data.define(
        :entry_name,
        :bindings,
        :definitions,
        :implementations,
        :constraints,
        :var_gen
      ) do
        def self.empty(var_gen = VarGen.new)
          Env[nil, {}, {}, {}, [], var_gen]
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

        def bind!(key, value)
          bindings
            .merge!(key => value)
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
              scheme_from_symbol(sym, registry, env)
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

        def scheme_from_symbol(sym, registry, env)
          var_gen = env.var_gen

          case sym
          in Symbol::ValueRef
            registry
              .lookup(sym)
              .then { scheme_from_symbol(it, registry, env) }

          in Symbol::InterfaceFunction | Symbol::StdlibFunction | Symbol::Variant | Symbol::InteropFunction
            Type
              .from_symbol(sym, registry, var_gen)
              # TODO: Clean up
              .then { Inference::Helpers.generalize(env, it, it.respond_to?(:constraints) ? it.constraints : []) }

          in Symbol::Function
            Type
              .from_symbol(sym, registry, var_gen)
              .then { Scheme.mono(it) }

          end
        end
      end
    end
  end
end

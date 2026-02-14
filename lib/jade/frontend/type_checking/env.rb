module Jade
  module Frontend
    module TypeChecking
      TypeDef = Data.define(:qualified_nam, :type_params, :body)

      Env = Data.define(:entry_name, :bindings, :definitions) do
        def self.empty
          Env[nil, {}, {}]
        end

        def self.load(entry, registry, var_gen)
          half_loaded = entry
            .values
            .reduce(empty.with(entry_name: entry.name)) do |env, (unq, sym)|
              Type.from_symbol(sym, registry, var_gen)
                .then { Inference::Helpers.generalize(env, it) }
                .then { env.bind(sym.qualified_name, it) }
            end

          entry
            .types
            .reduce(half_loaded) do |env, (unq, sym)|
              case sym
              in Symbol::Struct
                type_params, type_params_map = sym
                  .type_params
                  .map { Type.send(:from_symbol_r, it, registry, var_gen, {}) }

                Type
                  .send(:from_symbol_r, sym.record_type, registry, var_gen, type_params_map)
                  .first
                  .then { TypeDef[sym.qualified_name, type_params, it] }
                  .then { env.define(sym.qualified_name, it) }
              else
                next env
              end
            end
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
      end
    end
  end
end

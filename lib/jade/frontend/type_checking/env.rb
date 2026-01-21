module Jade
  module Frontend
    module TypeChecking
      Env = Data.define(:entry_name, :bindings) do
        def self.empty
          Env[nil, {}]
        end

        def self.load(entry, registry, var_gen)
          entry
            .values
            .reduce(empty.with(entry_name: entry.name)) do |env, (unq, sym)|
              Type.from_symbol(sym, registry, var_gen)
                .then { Inference::Helpers.generalize(env, it) }
                .then { env.bind(sym.qualified_name, it) }
            end
        end

        def bind(key, value)
          bindings
            .merge(key => value)
            .then { with(bindings: it) }
        end

        def lookup(key)
          bindings[key]
        end

        def free_vars
          bindings.values.flat_map(&:free_vars).to_set.to_a
        end
      end
    end
  end
end

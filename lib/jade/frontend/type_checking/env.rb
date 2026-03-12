module Jade
  module Frontend
    module TypeChecking
      class EnvEntry
        attr_accessor :type
        attr_reader :signature

        def initialize(type, signature)
          @type = type
          @signature = signature
        end

        def free_vars
          Scheme.mono(type).free_vars
        end

        def quantified
          Scheme.mono(type).quantified
        end
      end

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

        def fresh(name = nil)
          var_gen.fresh(name)
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
          case bindings[key]
          in EnvEntry => entry
            entry
              .type
              .then { Scheme.mono(it) }
          in Scheme => scheme
            scheme
          end
            .then { Instantiation.instantiate(it, var_gen) }
        end

        def lookup_def(key)
          definitions[key]
        end

        def free_vars
          bindings.values.flat_map(&:free_vars).to_set.to_a
        end

        def add_constraints!(other_constraints)
          constraints << other_constraints
          self
        end

        def load_bindings(entry, registry)
          entry
            .values
            .reduce(self) do |env, (unq, sym)|
              if sym.module_name == entry.name && !sym.is_a?(Symbol::Variant) && !sym.is_a?(Symbol::Struct)
                scheme_from_symbol(sym, registry, env)
                  .then { EnvEntry.new(env.fresh, it) }
                  .then { env.bind(sym.qualified_name, it) }
                
              else
                scheme_from_symbol(sym, registry, env)
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

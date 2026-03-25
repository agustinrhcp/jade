module Jade
  module Frontend
    module TypeChecking
      Placeholder = Data.define(:type, :constraints) do
        def free_vars
          type.unbound_vars + constraints.flat_map(&:unbound_vars)
        end
      end

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

        def finalize
          bindings
            .map do |(k, binding)|
              case binding
              in Placeholder(type:, constraints:)
                Inference::Helpers.generalize(
                  without_binding(k),
                  substitution.apply(type),
                  constraints
                    .map { substitution.apply(it) }
                    .filter { it.unbound_vars.empty? }
                    .uniq
                )
                  .then { acc.bind(k, it) }
                  
              else
                next acc
              end
            end
            .to_h
            .then { with(bindings: it) }
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

        def lookup_for_def(key)
          type, constraints =
            case bindings[key]
            in Scheme => scheme
              Instantiation.instantiate(scheme, var_gen)

            in Placeholder => placeholder 
              [placeholder.type, placeholder.constraints]
            end

          Result.init(
            type,
            constraints,
          )
        end

        def lookup(key)
            type, constraints =
              case bindings[key]
              in Scheme => scheme
                Instantiation.instantiate(scheme, var_gen)

              in Placeholder => placeholder
                Scheme[placeholder.free_vars, placeholder.type, placeholder.constraints]
                  .then { Instantiation.instantiate(it, var_gen) }

              # in Placeholder => placeholder 
              #   # TODO: if looking up current function (recursion)
              #   [placeholder.type, placeholder.constraints]
              end

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
            case sym
            in Symbol::Function
              Type
                .from_symbol(sym, registry, env.var_gen)
                .then { Placeholder[*it] }

            in Symbol::InterfaceFunction | Symbol::StdlibFunction | Symbol::Constructor |
              Symbol::InteropFunction

              Type
                .from_symbol(sym, registry, env.var_gen)
                .then { Inference::Helpers.generalize(env, *it) }
            end
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

        # Need to remove the placeholder from the env
        #  else the placeholder vars are never quantifiable.
        def without_binding(binding_name)
          bindings
            .reject { |k, v| k == k}
            .then { with(bindings: it) }
        end
      end
    end
  end
end

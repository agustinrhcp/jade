require 'jade/frontend/type_checking/placeholder'
require 'jade/frontend/type_checking/scheme'
require 'jade/frontend/type_checking/var_gen'

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
          binding = bindings[key]

          type, constraints =
            case bindings[key]
            in Scheme => scheme
              Instantiation.instantiate(scheme, var_gen)

            in Placeholder => placeholder
              Scheme[placeholder.free_vars, placeholder.type, placeholder.constraints]
                .then { Instantiation.instantiate(it, var_gen) }
            end

          Result.init(type)
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
      end
    end
  end
end

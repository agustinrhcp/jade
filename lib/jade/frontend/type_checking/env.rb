require 'jade/frontend/type_checking/placeholder'
require 'jade/frontend/type_checking/scheme'
require 'jade/frontend/type_checking/var_gen'

module Jade
  module Frontend
    module TypeChecking
      Env = Data.define(
        :entry_name, :bindings, :substitution,
        :definitions, :var_gen, :node_types,
      ) do
        def self.empty(var_gen = VarGen.new)
          Env[nil, {}, Substitution::EMPTY, {}, var_gen, {}]
        end

        def fresh
          var_gen.fresh
        end

        def bind(key, value)
          bindings
            .merge(key => value)
            .then { with(bindings: it) }
        end

        def pin_type(node_id, type)
          with(node_types: node_types.merge(node_id => type))
        end

        # Post-finalize, apply the env's substitution to every pinned
        # type so stored types are canonical (no leftover Type::Var that
        # the substitution would resolve).
        def canonicalize_node_types
          node_types
            .transform_values { substitution.apply(it) }
            .then { with(node_types: it) }
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

          Result.init(type, constraints)
        end

        def lookup_def(key)
          definitions[key]
        end

        def free_vars
          bindings
            .values
            .flat_map(&:free_vars)
            .flat_map { substitution.apply(it).unbound_vars }
            .uniq(&:id)
        end

        def composose_substitution(sub)
          with(substitution: substitution.compose(sub))
        end
      end
    end
  end
end

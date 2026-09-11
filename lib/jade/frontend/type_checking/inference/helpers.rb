require 'jade/frontend/type_checking/generalization'
require 'jade/frontend/type_checking/instantiation'

module Jade
  module Frontend
    module TypeChecking
      module Inference
        module Helpers
          extend self

          def unify(actual, expected)
            Unification.unify(actual, expected)
          end

          def instantiate(scheme, var_gen)
            Instantiation.instantiate(scheme, var_gen)
          end

          def generalize(env, type, constraints = [])
            Generalization.generalize(env, type, constraints)
          end

          def check(node, registry, env, expected_type)
            TypeChecking.check_node(node, registry, env, expected_type)
          end

          def type_from_symbol(symbol, registry, var_gen)
            Type.from_symbol(symbol, registry, var_gen)
          end

          def attach_markers(result)
            result
              .constraints
              .select { it.type.is_a?(Type::Var) && it.index != :unindex }
              .each { Constraints.attach_dictionary(it, it) }

            result
          end

          def type_mismatch(state, node)
            ->(error) do
              Error::TypeMismatch.new(
                state.env.entry_name,
                node.range,
                expected: error.expected,
                actual: error.actual,
              )
            end
          end
        end
      end
    end
  end
end

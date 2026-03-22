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
        end
      end
    end
  end
end

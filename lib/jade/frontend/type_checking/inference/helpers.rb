module Jade
  module Frontend
    module TypeChecking
      module Inference
        module Helpers
          extend self

          def with_span(node, constraints)
            constraints.map { it.with(span: node.range) }
          end

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

          def solve_constraints(constraints, registry, env)
            constraints
              .filter_map do |cons|
                next if cons.type.is_a?(Type::Var)

                implementation = case cons.type
                  in Type::Application(constructor:, args: [])
                    [
                      cons.interface,
                      cons.type.constructor.name,
                    ]
                  else
                    [
                      cons.interface,
                      cons.type.to_s,
                    ]
                  end
                  .then { registry.implementations[it] }

                next if implementation

                Error::UnsatisfiedConstraint.new(
                  env.entry_name,
                  nil,
                  constraint: cons,
                )
              end
          end
        end
      end
    end
  end
end

module Jade
  module Frontend
    module TypeChecking
      module Inference
        module FunctionDeclaration
          extend Helpers
          extend self

          def infer(node, registry, env, _)
            node => AST::FunctionDeclaration(symbol:, body:, params:)

            fn_type, constraints = env
              .lookup(symbol.qualified_name)
              .then { instantiate(it, env.var_gen) }

            body_r = fn_type
              .args
              .zip(params)
              .reduce(env) do |body_env, (t, p)|
                body_env.bind(p.name, Scheme[[], t, constraints])
              end
              .then { check(body, registry, it, Expected.auth(fn_type.return_type)) }
              .and_unify(fn_type.return_type.make_rigid) do |error|
                Error::FunctionBodyTypeMismatch.new(
                  env.entry_name,
                  node.range,
                  expected: error.expected,
                  actual: error.actual,
                  function_name: node.name,
                )
              end

            scheme = fn_type
              .then { body_r.substitution.apply(it) }
              .then { generalize(env, it, body_r.constraints) }

            scheme
              .then { env.bind!(symbol.qualified_name, it) }

            cons_errors = solve_constraints(scheme, env, registry)

            body_r
              .then { it.with(type: Type.unit) }
              .add_errors(cons_errors)
          end

          private

          def solve_constraints(scheme, env, registry)
            scheme
              .constraints
              .filter_map do |cons|
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

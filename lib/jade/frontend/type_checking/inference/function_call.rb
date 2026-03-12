module Jade
  module Frontend
    module TypeChecking
      module Inference
        module FunctionCall
          extend Helpers
          extend self

          def infer(node, registry, env, expected)
            node => AST::FunctionCall(callee:, args:)

            callee_r = check(callee, registry, env, Expected.non_auth(env.fresh))

            args
              .reduce(Result.init([], env)) do |acc, arg|
                check(arg, registry, acc.env, Expected.non_auth(env.fresh))
                  .then { it.with(type: acc.type + [it.type]) }
                  .then { acc.merge(it) }
              end
              # TODO: What if callee_r type is not a function!??
              .then { it.with(type: Type.function(it.type, env.fresh)) }
              .then { callee_r.merge(it) }
              .and_unify(callee_r.type) do |e|
                Error::FunctionCallTypeMismatch.new(
                  env.entry_name,
                  node.range,
                  expected: e.expected,
                  actual: e.actual,
                )
              end
              .then { it.with(type: it.type.return_type) }
              .and_unify(expected.type) do |e|
                Error::FunctionCallTypeMismatch.new(
                  env.entry_name,
                  node.range,
                  expected: e.expected,
                  actual: e.actual,
                )
              end
              .then do |it|
                it.add_errors(solve_constraints(it.constraints, registry, env))
              end
              .tap(&add_dictionaries_to_node(node))
          end

          private

          def add_dictionaries_to_node(node)
            ->(result) do
              result
                .constraints
                # mutates the node
                .then { node.dictionaries.concat(it) }
            end
          end
        end
      end
    end
  end
end

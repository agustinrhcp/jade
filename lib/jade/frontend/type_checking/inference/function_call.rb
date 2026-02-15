module Jade
  module Frontend
    module TypeChecking
      module Inference
        module FunctionCall
          extend Helpers
          extend self

          def infer(node, registry, env, var_gen, expected)
            node => AST::FunctionCall(callee:, args:)

            callee_r = check(callee, registry, env, var_gen, Expected.non_auth(var_gen))

            args
              .reduce(Result.new([], Substitution.new, env, [])) do |acc, arg|
                check(arg, registry, acc.env, var_gen, Expected.non_auth(var_gen))
                  .then { it.with(type: acc.type + [it.type]) }
                  .compose_substitution(acc.substitution)
                  .add_errors(acc.errors)
              end
              # TODO: What if callee_r type is not a function!??
              .then { it.with(type: Type.function(it.type, callee_r.type.return_type)) }
              .add_errors(callee_r.errors)
              .compose_substitution(callee_r.substitution)
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
          end
        end
      end
    end
  end
end

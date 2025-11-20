module Jade
  module Frontend
    module TypeChecking
      module Inference
        module FunctionCall
          extend Helpers
          extend self

          def infer(node, registry, env, var_gen)
            node => AST::FunctionCall(callee:, args:)

            callee_r = check(callee, registry, env, var_gen)

            args
              .reduce(Result.new([], Substitution.new, env, [])) do |acc, arg|
                check(arg, registry, acc.env, var_gen)
                  .then { it.with(type: acc.type + [it.type]) }
                  .compose_substitution(acc.substitution)
                  .add_errors(acc.errors)
              end
              .then { it.with(type: Type.function(it.type, Type.var(var_gen.fresh))) }
              .add_errors(callee_r.errors)
              .compose_substitution(callee_r.substitution)
              .and_unify(callee_r.type) do |e|
                FunctionCallTypeMismatchError.new(node, e.expected, e.actual)
              end
              .then { it.with(type: it.type.return_type) }
          end
        end
      end
    end
  end
end

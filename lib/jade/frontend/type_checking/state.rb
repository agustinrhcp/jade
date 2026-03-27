module Jade
  module Frontend
    module TypeChecking
      State = Data.define(:env, :errors) do
        def self.init(env)
          new(env, [])
        end

        def unify_result(result, right, rigid_vars = [], &block)
          unify(result.type, right, rigid_vars, &block)
            .then { [it, result.apply(it.env.substitution)] }
        end

        def unify(left, right, rigid_vars = [], &block)
          applied_left = env.substitution.apply(left)
          applied_right = env.substitution.apply(right)

          case Unification.unify(applied_left, applied_right, env, Unification::Context[rigid_vars])
          in Ok(sub)
            with(env: env.composose_substitution(sub))

          in Err(error)
            with(errors: errors + [block.call(error)])
          end
        end

        def add_errors(more_errors)
          with(errors: errors + more_errors)
        end

        def fresh
          env.fresh
        end

        def bind(key, value)
          with(env: env.bind(key, value))
        end

        def to_result
          if errors.any?
            Err[errors]
          else
            Ok[env]
          end
        end
      end
    end
  end
end

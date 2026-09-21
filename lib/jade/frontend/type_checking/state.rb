module Jade
  module Frontend
    module TypeChecking
      State = Data.define(:env, :errors, :skip_constraints, :impl_requirements, :pattern_checks) do
        def self.init(env, skip_constraints: false)
          new(env, [], skip_constraints, {}, [])
        end

        # Coverage is decided once inference is done: a pattern in a lambda is
        # checked before the call that gives the lambda's parameter its type,
        # so the subject can still be a variable here.
        def defer_patterns(patterns, range, type)
          with(pattern_checks: pattern_checks + [[patterns, range, type]])
        end

        def require_impl(key, constraints)
          return self if constraints.empty?

          impl_requirements
            .merge(key => constraints) { |_, old, new| (old + new).uniq }
            .then { with(impl_requirements: it) }
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
            with(
              env: env.composose_substitution(error.partial_sub),
              errors: errors + [block.call(error)],
            )
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

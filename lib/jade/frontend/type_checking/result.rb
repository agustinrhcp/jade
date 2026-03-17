module Jade
  module Frontend
    module TypeChecking
      State = Data.define(:env, :errors) do
        def self.init(env)
          new(env, [])
        end

        def unify_result(result, right, &block)
          unify(result.type, right, &block)
            .then { [it, result.apply(it.env.substitution)] }
        end

        def unify(left, right, &block)
          applied_left = env.substitution.apply(left)
          applied_right = env.substitution.apply(right)

          case Unification.unify(applied_left, applied_right, env)
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

      Result = Data.define(:type, :constraints) do
        def self.init(type, constraints = [])
          new(type:, constraints:)
        end

        def apply(substitution)
          with(
            type: substitution.apply(type),
            constraints: constraints.map { it.with(type: substitution.apply(it.type)) },
          )
        end

        def map(&block)
          block
            .call(type)
            .then { with(type: it) }
        end

        def self.accumulator
          ResultAcc[types: [], constraints: []]
        end
      end

      ResultAcc = Data.define(:types, :constraints) do
        def add(result)
          with(
            types: types + [result.type],
            constraints: constraints + result.constraints,
          )
        end
      end
    end
  end
end

module Jade
  module Frontend
    module TypeChecking
      Result = Data.define(:type, :constraints, :substitution, :env, :errors) do
        def self.init(type, env, constraints = [])
          new(type:, constraints:, env:, errors: [], substitution: Substitution.new)
        end

        def and_unify(actual, &block)
          case Unification.unify(type, actual, env)
          in Ok(sub)
            compose_substitution(sub)
              .apply

          in Err(error)
            fail "block is mandatory" unless block

            add_errors([block.call(error)])
              .with(type: error.actual)
          end
        end

        def add_errors(more_errors)
          with(errors: errors + more_errors)
        end

        def add_constraints(cons)
          with(constraints: (constraints + cons).to_set.to_a)
        end

        def compose_substitution(sub)
          with(substitution: substitution.compose(sub))
        end

        def apply
          with(type: substitution.apply(type))
           .with(constraints: constraints.map { substitution.apply(it) })
        end

        def merge(other)
          other
            .add_errors(errors)
            .add_constraints(constraints)
            .compose_substitution(substitution)
        end

        def to_result
          if errors.any?
            Err[errors]
          else
            Ok[[type, env]]
          end
        end
      end
    end
  end
end

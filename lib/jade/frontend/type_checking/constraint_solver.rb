module Jade
  module Frontend
    module TypeChecking
      module ConstraintSolver
        extend self

        Result = Data.define(:unsolved, :errors) do
          def self.ok
            new([], [])
          end

          def self.error(error)
            new([], [error])
          end

          def self.unsolved(con)
            new([con], [])
          end

          def merge(other)
            with(unsolved: unsolved + other.unsolved)
              .with(errors: errors + other.errors)
          end
        end

        def solve_all(env, registry)
          env
            .constraints
            .reduce(Result.ok) do |acc, con|
              solve(con, registry, env)
                .merge(acc)
            end
        end

        def solve(cons, registry, env)
          return Result.unsolved(cons) if cons.type.is_a?(Type::Var)

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

          return Result.ok if implementation

          Error::UnsatisfiedConstraint
            .new(
              env.entry_name,
              cons.span,
              constraint: cons,
            )
            .then { Result.error(it) }
        end
      end
    end
  end
end

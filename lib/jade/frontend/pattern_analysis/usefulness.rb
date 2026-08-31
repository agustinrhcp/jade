module Jade
  module Frontend
    module PatternAnalysis
      # Maranget's other half: can any value reach `row` that the rows above it
      # did not already take? A branch that is not useful is dead code.
      module Usefulness
        extend self

        def useful?(matrix, row, env)
          return matrix.empty? if matrix.types.empty?

          type = matrix.types.first

          return false if Signature.uninhabited?(type)
          return expanded(matrix, row, env) if Signature.expandable?(type, env)

          # The row under test cuts the column too, so its own bounds have to
          # be in the split or it will not line up with the cases.
          split = Signature.of(type, matrix.heads + [row.first], env)

          case row.first
          in Wildcard
            open_column(matrix, row, split, env)

          in Interval
            split.covering(row.first).any? { narrowed(matrix, row, it, env) }

          in Literal(value:)
            split
              .covering(row.first)
              .then { it.empty? ? [ValueCase[value]] : it }
              .any? { narrowed(matrix, row, it, env) }

          # Deadness is a proof. A constructor this column's type does not have
          # yields none, so the branch stands.
          in Constructor
            split
              .covering(row.first)
              .then { it.empty? || it.any? { narrowed(matrix, row, it, env) } }
          end
        end

        private

        # A wildcard reaches whatever the rows above left open. When they name
        # every case of the type there is no such ground, and the question
        # moves inside the cases instead.
        def open_column(matrix, row, split, env)
          if split.covered_by?(matrix.heads)
            split.cases.any? { narrowed(matrix, row, it, env) }
          else
            useful?(matrix.default, row.drop(1), env)
          end
        end

        def narrowed(matrix, row, kase, env)
          head = row.first
          args =
            kase.matches?(head) ? head.args : Array.new(kase.arity) { Wildcard[] }

          useful?(matrix.specialize(kase), args + row.drop(1), env)
        end

        def expanded(matrix, row, env)
          fields = Signature.fields(matrix.types.first, env)

          useful?(matrix.expand(env), matrix.expand_row(row, fields), env)
        end
      end
    end
  end
end

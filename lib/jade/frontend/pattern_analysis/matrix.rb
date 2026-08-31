module Jade
  module Frontend
    module PatternAnalysis
      Matrix = Data.define(:rows, :types) do
        def self.wildcard(types)
          types
            .map { Wildcard[] }
            .then { Matrix[[it], types] }
        end

        def self.empty(types = [])
          Matrix[[], types]
        end

        def map
          rows
            .map { yield it }
            .then { with(rows: it) }
        end

        def empty?
          rows.empty?
        end

        def concat(other)
          with(rows: rows + other.rows)
        end

        def head_names
          rows.filter_map do |row|
            case row.first
            in Constructor(constructor: name) then name
            in Literal(value:) then value
            in Record | Wildcard then nil
            end
          end
        end

        # Rows the case can match, each opened up into the columns the case
        # carries. A row headed by a wildcard matches every case, and says
        # nothing about the columns it opens.
        def specialize(kase)
          rows
            .filter_map do |row|
              head = row.first

              if kase.matches?(head)
                head.args + row.drop(1)
              elsif head.wildcard?
                Array.new(kase.arity) { Wildcard[] } + row.drop(1)
              end
            end
            .then { Matrix[it, kase.arg_types + types.drop(1)] }
        end

        # The rows that survive when the first column is decided by no case at
        # all — only the ones that were not asking about it.
        def default
          rows
            .select { it.first.wildcard? }
            .map { it.drop(1) }
            .then { Matrix[it, types.drop(1)] }
        end

        def expand(env)
          fields = Signature.fields(types.first, env)

          map { |row| expand_row(row, fields) }
            .with(types: fields.values + types.drop(1))
        end

        def expand_row(row, fields)
          case row.first
          in Record(fields: matched)
            fields.keys.map { matched[it] || Wildcard[] } + row.drop(1)

          in Wildcard
            fields.keys.map { Wildcard[] } + row.drop(1)
          end
        end
      end
    end
  end
end

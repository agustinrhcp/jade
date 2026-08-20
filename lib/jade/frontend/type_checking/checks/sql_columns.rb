module Jade
  module Frontend
    module TypeChecking
      module Checks
        # jade-sql maps a struct's fields onto a table's columns by name. The
        # mapping derives, so nothing else ever compares the two — a field the
        # table has no column for reaches Postgres as invalid SQL.
        #
        # Both types are concrete at the call site, so the comparison belongs
        # here rather than in the type system. Checked here rather than in
        # jade-sql for the same reason `Deriving::Assignable` is: an extension
        # gem cannot add a pass. Inert without jade-sql, since nothing else
        # declares these functions.
        module SqlColumns
          extend self
          include Constraints::Deriving::Helpers

          TABLE = 'Sql.Table'
          EXPR = 'Sql.Expr'

          # Where the written value is, where the table is, and whether it
          # arrives wrapped in a list.
          TARGETS = {
            'Sql.Mutation.insert' => [0, 1, :bare],
            'Sql.Mutation.insert_all' => [0, 1, :list],
            'Sql.Mutation.update' => [0, 1, :bare],
          }.freeze

          def check(qualified_name, arg_types, registry, entry_name, span)
            TARGETS[qualified_name].then do |target|
              return [] unless target

              value_at, table_at, wrapper = target
              value = arg_types[value_at]
              table = arg_types[table_at]
              return [] if value.nil? || table.nil?

              compare(
                unwrap(value, wrapper),
                cols_of(table),
                registry, entry_name, span,
              )
            end
          end

          private

          def compare(value, cols, registry, entry_name, span)
            return [] if cols.nil?

            columns = columns_of(cols, registry)
            fields = fields_of(value, registry)
            return [] if columns.nil? || fields.nil?

            fields.filter_map { mismatch(it, columns, value, cols, entry_name, span) }
          end

          def mismatch((name, type), columns, value, cols, entry_name, span)
            column = column_name(name)

            case columns[column]
            in nil
              Error::UnknownColumn.new(
                entry_name, span,
                struct: name_of(value), field: name, table: name_of(cols),
              )

            in ^type
              nil

            in found
              Error::ColumnTypeMismatch.new(
                entry_name, span,
                struct: name_of(value), field: name, table: name_of(cols),
                column:, expected: found, actual: type,
              )
            end
          end

          # `Table(c, m, k)` — the columns are its first argument.
          def cols_of(table)
            case table
            in Type::Application(constructor: Type::Constructor(name: TABLE), args: [cols, *])
              cols

            else nil
            end
          end

          # Each column is an `Expr(t)` whose `t` is what the field has to be.
          def columns_of(cols, registry)
            fields_of(cols, registry)
              &.to_h { |field, type| [column_name(field), unwrap_expr(type)] }
          end

          def fields_of(type, registry)
            case type
            in Type::Application(constructor: Type::Constructor(name:), args:)
              Symbol
                .type_ref_from_qualified_name(name)
                .then { registry.lookup(it) }
                .then { (it in Symbol::Struct) ? struct_fields(it, args, registry) : nil }

            else nil
            end
          end

          def unwrap(type, wrapper)
            case [wrapper, type]
            in [:list, Type::Application(constructor: Type::Constructor(name: 'List.List'), args: [inner])]
              inner

            else type
            end
          end

          def unwrap_expr(type)
            case type
            in Type::Application(constructor: Type::Constructor(name: EXPR), args: [inner])
              inner

            else type
            end
          end

          def name_of(type)
            case type
            in Type::Application(constructor: Type::Constructor(name:), args: _)
              name.split('.').last

            else type.to_s
            end
          end

          # The generator renames a column that collides with a jade keyword,
          # so `type_` maps back to the `type` it came from.
          def column_name(field)
            field
              .to_s
              .then { it.end_with?('_') ? it.delete_suffix('_') : it }
              .then { Lexer::KEYWORDS.include?(it) ? it : field.to_s }
          end
        end
      end
    end
  end
end

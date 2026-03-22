require 'spec_helper'

require 'jade'
require 'jade/module_loader'

module Jade
  describe 'SQL' do
    include_context 'with test compiler'

    describe 'SQL' do
      before do
        test_compiler.require('sql', sql_source)
      end

      let(:sql_source) do
        <<~JADE
          module Sql exposing(column, from)

          struct Expr(a) = { to_sql: String, type_: a }

          struct From = { alias_: String }
          struct Query = { from: From, options: QueryOptions }
          struct QueryOptions = { selects: List(String), wheres: List(String) }

          type SqlString = SqlString
          type SqlBool = SqlBool
          type SqlInt  = SqlInt

          struct Table(a) = { name: String, alias_: String, columns: (String -> a) }

          def table(name: String, alias_: String, columns: (String -> a)) -> Table(a)
            Table(name, alias_, columns)
          end

          def column(table_name_or_alias: String, column_name: String, type_: a) -> Expr(a)
            sql = [table_name_or_alias, column_name]
              |> List.filter((part) -> { part |> String.is_empty |> Basics.not })
              |> String.join(".")

            Expr(sql, type_)
          end

          def from(table_: Table(a), select_fn: (a -> QueryOptions)) -> Query
            Query(
              From(table_.alias_),
              table_.alias_ |> table_.columns |> select_fn
            )
          end
        JADE
      end

      it do
        expect(Sql.column.call('patients', 'ident', 'string'))
          .to be_a(Sql::Expr)
          .and have_attributes(to_sql: 'patients.ident')
      end
    end
  end
end

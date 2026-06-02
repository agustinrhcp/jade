require 'spec_helper'

require 'jade'
require 'jade/module_loader'
require_relative '../../extensions/jade_sql/lib/jade-sql'

module Jade
  describe 'Sql (extension)' do
    include_context 'with test compiler'

    describe 'column' do
      it 'builds a qualified column reference with no params' do
        test_compiler.require('app', <<~JADE)
          module App exposing (make_col)

          import Sql exposing (Expr, column)


          def make_col -> Expr(a)
            column("p", "name")
          end
        JADE

        App::Internal.make_col.then do |expr|
          expect(expr.sql).to eql 'p.name'
          expect(expr.params).to eql []
        end
      end
    end

    describe 'to_expr (polymorphic via SqlEncodable)' do
      it 'encodes an Int into VInt' do
        test_compiler.require('app', <<~JADE)
          module App exposing (make_expr)

          import Sql exposing (Expr, to_expr)


          def make_expr -> Expr(Int)
            to_expr(42)
          end
        JADE

        App::Internal.make_expr.then do |expr|
          expect(expr.sql).to eql '?'
          expect(expr.params).to eql [42]
        end
      end

      it 'encodes a String into VStr' do
        test_compiler.require('app', <<~JADE)
          module App exposing (make_expr)

          import Sql exposing (Expr, to_expr)


          def make_expr -> Expr(String)
            to_expr("paul")
          end
        JADE

        App::Internal.make_expr.then do |expr|
          expect(expr.params).to eql ['paul']
        end
      end

      it 'encodes Just(n) recursively as VInt' do
        test_compiler.require('app', <<~JADE)
          module App exposing (make_expr)

          import Sql exposing (Expr, to_expr)


          def make_expr -> Expr(Maybe(Int))
            to_expr(Just(12))
          end
        JADE

        App::Internal.make_expr.then do |expr|
          expect(expr.params).to eql [12]
        end
      end

      it 'encodes Nothing as VNull' do
        test_compiler.require('app', <<~JADE)
          module App exposing (make_expr)

          import Sql exposing (Expr, to_expr)


          def make_expr -> Expr(Maybe(Int))
            to_expr(Nothing)
          end
        JADE

        App::Internal.make_expr.then do |expr|
          expect(expr.params).to eql [nil]
        end
      end
    end

    describe 'eq' do
      it 'merges sql and params, in order' do
        test_compiler.require('app', <<~JADE)
          module App exposing (predicate)

          import Sql exposing (Expr, column, eq, to_expr)


          def predicate -> Expr(Bool)
            column("p", "age") |> eq(to_expr(18))
          end
        JADE

        App::Internal.predicate.then do |expr|
          expect(expr.sql).to eql 'p.age = ?'
          expect(expr.params).to eql [18]
        end
      end
    end

    describe 'is_null' do
      it 'appends IS NULL' do
        test_compiler.require('app', <<~JADE)
          module App exposing (predicate)

          import Sql exposing (Expr, column, is_null)


          def predicate -> Expr(Bool)
            column("p", "age") |> is_null
          end
        JADE

        App::Internal.predicate.then do |expr|
          expect(expr.sql).to eql 'p.age IS NULL'
          expect(expr.params).to eql []
        end
      end
    end

    describe 'and' do
      it 'joins predicates with AND' do
        test_compiler.require('app', <<~JADE)
          module App exposing (predicate)

          import Sql exposing (Expr, and, column, eq, to_expr)


          def predicate -> Expr(Bool)
            a = column("p", "a") |> eq(to_expr(1))
            b = column("p", "b") |> eq(to_expr(2))

            a |> and(b)
          end
        JADE

        App::Internal.predicate.then do |expr|
          expect(expr.sql).to eql 'p.a = ? AND p.b = ?'
          expect(expr.params).to eql [1, 2]
        end
      end
    end

    describe 'cast' do
      it 'rewraps the phantom type without touching sql or params' do
        test_compiler.require('app', <<~JADE)
          module App exposing (recast)

          import Sql exposing (Expr, cast, column)


          def recast -> Expr(Bool)
            column("p", "kind") |> cast
          end
        JADE

        App::Internal.recast.then do |expr|
          expect(expr.sql).to eql 'p.kind'
          expect(expr.params).to eql []
        end
      end
    end

    describe 'aggregates / coalesce / neg' do
      let(:source) do
        <<~JADE
          module App exposing (
            coalesced,
            count_col,
            count_star,
            negated,
            sum_col,
          )

          import Sql exposing (
            Expr,
            coalesce,
            column,
            count,
            count_all,
            neg,
            sum,
            to_expr,
          )


          def sum_col -> Expr(Maybe(Int))
            column("p", "amount") |> sum
          end


          def count_col -> Expr(Int)
            column("p", "id") |> count
          end


          def count_star -> Expr(Int)
            count_all
          end


          def coalesced -> Expr(Int)
            coalesce(sum(column("p", "amount")), to_expr(0))
          end


          def negated -> Expr(Int)
            column("p", "amount") |> neg
          end
        JADE
      end

      before { test_compiler.require('app', source) }

      it 'sum wraps a column' do
        App::Internal.sum_col.then do |expr|
          expect(expr.sql).to eql 'SUM(p.amount)'
          expect(expr.params).to eql []
        end
      end

      it 'count and count_all' do
        App::Internal.count_col.then { |e| expect(e.sql).to eql 'COUNT(p.id)' }
        App::Internal.count_star.then { |e| expect(e.sql).to eql 'COUNT(*)' }
      end

      it 'coalesce wraps a Maybe expr with a default' do
        App::Internal.coalesced.then do |expr|
          expect(expr.sql).to eql 'COALESCE(SUM(p.amount), ?)'
          expect(expr.params).to eql [0]
        end
      end

      it 'neg negates an Int expr' do
        App::Internal.negated.then { |e| expect(e.sql).to eql '-(p.amount)' }
      end
    end

    describe 'from + where via postfix' do
      let(:source) do
        <<~JADE
          module App exposing (named_paul)

          import Sql exposing (Expr, Table, column, columns, eq, table, to_expr)
          import Sql.Query exposing (Q, from, where)


          struct PersonsCols = {
            id: Expr(Int),
            name: Expr(String)
          }


          struct MaybePersonsCols = {
            id: Expr(Maybe(Int)),
            name: Expr(Maybe(String))
          }


          def persons -> Table(PersonsCols, MaybePersonsCols)
            table(
              "persons",
              "p",
              (a) -> { PersonsCols(column(a, "id"), column(a, "name")) },
              (a) -> { MaybePersonsCols(column(a, "id"), column(a, "name")) },
              ["id"],
            )
          end


          def named_paul -> Q(PersonsCols)
            p_cols = columns(persons, "p")

            from(persons) |> where(p_cols.name |> eq(to_expr("Paul")))
          end
        JADE
      end

      it 'records the table and where clause' do
        test_compiler.require('app', source)

        App::Internal.named_paul.then do |q|
          expect(q.tables.size).to eql 1
          expect(q.tables.first.name).to eql 'persons'
          expect(q.tables.first.alias_).to eql 'p'
          expect(q.wheres.size).to eql 1
          expect(q.wheres.first.sql).to eql 'p.name = ?'
          expect(q.wheres.first.params).to eql ['Paul']
        end
      end
    end

    describe 'inner join via bind chain' do
      let(:source) do
        <<~JADE
          module App exposing (persons_with_orders)

          import Sql exposing (Expr, Table, column, eq, table)
          import Sql.Query exposing (Q, from, join)


          struct PersonsCols = { id: Expr(Int) }


          struct MaybePersonsCols = { id: Expr(Maybe(Int)) }


          struct OrdersCols = {
            id: Expr(Int),
            person_id: Expr(Int)
          }


          struct MaybeOrdersCols = {
            id: Expr(Maybe(Int)),
            person_id: Expr(Maybe(Int))
          }


          def persons -> Table(PersonsCols, MaybePersonsCols)
            table(
              "persons",
              "p",
              (a) -> { PersonsCols(column(a, "id")) },
              (a) -> { MaybePersonsCols(column(a, "id")) },
              ["id"],
            )
          end


          def orders -> Table(OrdersCols, MaybeOrdersCols)
            table(
              "orders",
              "o",
              (a) -> { OrdersCols(column(a, "id"), column(a, "person_id")) },
              (a) -> { MaybeOrdersCols(column(a, "id"), column(a, "person_id")) },
              ["id"],
            )
          end


          def persons_with_orders -> Q(OrdersCols)
            p <- from(persons)

            join(orders, (o) -> { p.id |> eq(o.person_id) })
          end
        JADE
      end

      it 'records the inner join with predicate' do
        test_compiler.require('app', source)

        App::Internal.persons_with_orders.then do |q|
          expect(q.tables.size).to eql 1
          expect(q.tables.first.name).to eql 'persons'
          expect(q.joins.size).to eql 1
          j = q.joins.first
          expect(j.kind).to eql Sql::Query::InnerJ[]
          expect(j.name).to eql 'orders'
          expect(j.alias_).to eql 'o'
          expect(j.on.sql).to eql 'p.id = o.person_id'
        end
      end
    end

    describe 'aliased — self-join with explicit alias' do
      let(:source) do
        <<~JADE
          module App exposing (parents_and_kids)

          import Sql exposing (Expr, Table, aliased, column, eq, table)
          import Sql.Query exposing (Q, from, join)


          struct PersonsCols = {
            id: Expr(Int),
            parent_id: Expr(Int)
          }


          struct MaybePersonsCols = {
            id: Expr(Maybe(Int)),
            parent_id: Expr(Maybe(Int))
          }


          def persons -> Table(PersonsCols, MaybePersonsCols)
            table(
              "persons",
              "persons",
              (a) -> { PersonsCols(column(a, "id"), column(a, "parent_id")) },
              (a) -> { MaybePersonsCols(column(a, "id"), column(a, "parent_id")) },
              ["id"],
            )
          end


          def parents_and_kids -> Q(PersonsCols)
            p <- from(persons)

            persons
              |> aliased("c")
              |> join((c) -> { p.id |> eq(c.parent_id) })
          end
        JADE
      end

      it 'overrides the join alias and qualifies its columns' do
        test_compiler.require('app', source)

        App::Internal.parents_and_kids.then do |q|
          expect(q.tables.first.alias_).to eql 'persons'
          expect(q.joins.size).to eql 1
          j = q.joins.first
          expect(j.name).to eql 'persons'
          expect(j.alias_).to eql 'c'
          expect(j.on.sql).to eql 'persons.id = c.parent_id'
        end
      end
    end

    describe 'left_join via bind chain' do
      let(:source) do
        <<~JADE
          module App exposing (persons_with_optional_orders)

          import Sql exposing (Expr, Table, column, eq, table)
          import Sql.Query exposing (Q, from, left_join)


          struct PersonsCols = { id: Expr(Int) }


          struct MaybePersonsCols = { id: Expr(Maybe(Int)) }


          struct OrdersCols = {
            id: Expr(Int),
            person_id: Expr(Int)
          }


          struct MaybeOrdersCols = {
            id: Expr(Maybe(Int)),
            person_id: Expr(Maybe(Int))
          }


          def persons -> Table(PersonsCols, MaybePersonsCols)
            table(
              "persons",
              "p",
              (a) -> { PersonsCols(column(a, "id")) },
              (a) -> { MaybePersonsCols(column(a, "id")) },
              ["id"],
            )
          end


          def orders -> Table(OrdersCols, MaybeOrdersCols)
            table(
              "orders",
              "o",
              (a) -> { OrdersCols(column(a, "id"), column(a, "person_id")) },
              (a) -> { MaybeOrdersCols(column(a, "id"), column(a, "person_id")) },
              ["id"],
            )
          end


          def persons_with_optional_orders -> Q(MaybeOrdersCols)
            p <- from(persons)

            left_join(orders, (o) -> { p.id |> eq(o.person_id) })
          end
        JADE
      end

      it 'records left_join with strict on-predicate, maybe result' do
        test_compiler.require('app', source)

        App::Internal.persons_with_optional_orders.then do |q|
          j = q.joins.first
          expect(j.kind).to eql Sql::Query::LeftJ[]
          expect(j.on.sql).to eql 'p.id = o.person_id'
        end
      end
    end

    describe 'inner join on a nullable FK requires nullable() lift' do
      let(:source) do
        <<~JADE
          module App exposing (persons_with_companies)

          import Sql exposing (Expr, Table, column, eq, nullable, table)
          import Sql.Query exposing (Q, from, join)


          struct PersonsCols = {
            id: Expr(Int),
            company_id: Expr(Maybe(Int))
          }


          struct MaybePersonsCols = {
            id: Expr(Maybe(Int)),
            company_id: Expr(Maybe(Int))
          }


          struct CompaniesCols = { id: Expr(Int) }


          struct MaybeCompaniesCols = { id: Expr(Maybe(Int)) }


          def persons -> Table(PersonsCols, MaybePersonsCols)
            table(
              "persons",
              "p",
              (a) -> { PersonsCols(column(a, "id"), column(a, "company_id")) },
              (a) -> { MaybePersonsCols(column(a, "id"), column(a, "company_id")) },
              ["id"],
            )
          end


          def companies -> Table(CompaniesCols, MaybeCompaniesCols)
            table(
              "companies",
              "c",
              (a) -> { CompaniesCols(column(a, "id")) },
              (a) -> { MaybeCompaniesCols(column(a, "id")) },
              ["id"],
            )
          end


          def persons_with_companies -> Q(CompaniesCols)
            p <- from(persons)

            join(companies, (c) -> { p.company_id |> eq(c.id |> nullable) })
          end
        JADE
      end

      it 'compiles when c.id is lifted to Maybe(Int)' do
        test_compiler.require('app', source)

        App::Internal.persons_with_companies.then do |q|
          j = q.joins.first
          expect(j.on.sql).to eql 'p.company_id = c.id'
        end
      end
    end

    describe 'select pipeline via bind chain (waits for placeholders)' do
      let(:adults_source) do
        <<~JADE
          module App exposing (adults_query)

          import Sql exposing (Expr, Selector, Table, column, eq, table, to_expr)
          import Sql.Query exposing (Q, field, from, select, where)


          struct PersonsCols = {
            id: Expr(Int),
            name: Expr(String),
            age: Expr(Int)
          }


          struct MaybePersonsCols = {
            id: Expr(Maybe(Int)),
            name: Expr(Maybe(String)),
            age: Expr(Maybe(Int))
          }


          struct Person = {
            id: Int,
            name: String,
            age: Int
          }


          def persons -> Table(PersonsCols, MaybePersonsCols)
            table(
              "persons",
              "p",
              (a) -> { PersonsCols(column(a, "id"), column(a, "name"), column(a, "age")) },
              (a) -> { MaybePersonsCols(column(a, "id"), column(a, "name"), column(a, "age")) },
              ["id"],
            )
          end


          def adults_query -> Q(Selector(Person))
            p <- from(persons)

            select(Person(_, _, _))
              |> field(p.id)
              |> field(p.name)
              |> field(p.age)
          end
        JADE
      end

      it 'projects the selected columns in declared order' do
        test_compiler.require('app', adults_source)

        App::Internal.adults_query.then do |q|
          expect(q.result.columns_sql).to eql ['p.id', 'p.name', 'p.age']
        end
      end
    end

    describe 'to_sql renders joined queries with params in clause order' do
      let(:source) do
        <<~JADE
          module App exposing (rendered)

          import Sql exposing (Expr, Selector, Table, column, eq, is_not_null, table, to_expr)
          import Sql.Query exposing (Q, field, from, join, select, to_sql, where)
          import Decode exposing (Value)


          struct PersonsCols = {
            id: Expr(Int),
            name: Expr(String),
            age: Expr(Maybe(Int))
          }


          struct MaybePersonsCols = {
            id: Expr(Maybe(Int)),
            name: Expr(Maybe(String)),
            age: Expr(Maybe(Int))
          }


          struct OrdersCols = {
            id: Expr(Int),
            person_id: Expr(Int),
            total: Expr(Int)
          }


          struct MaybeOrdersCols = {
            id: Expr(Maybe(Int)),
            person_id: Expr(Maybe(Int)),
            total: Expr(Maybe(Int))
          }


          struct Row = {
            id: Int,
            name: String,
            total: Int
          }


          def persons -> Table(PersonsCols, MaybePersonsCols)
            table(
              "persons",
              "p",
              (a) -> { PersonsCols(column(a, "id"), column(a, "name"), column(a, "age")) },
              (a) -> { MaybePersonsCols(column(a, "id"), column(a, "name"), column(a, "age")) },
              ["id"],
            )
          end


          def orders -> Table(OrdersCols, MaybeOrdersCols)
            table(
              "orders",
              "o",
              (a) -> { OrdersCols(column(a, "id"), column(a, "person_id"), column(a, "total")) },
              (a) -> { MaybeOrdersCols(column(a, "id"), column(a, "person_id"), column(a, "total")) },
              ["id"],
            )
          end


          def query -> Q(Selector(Row))
            p <- from(persons)
            o <- join(orders, (o) -> { p.id |> eq(o.person_id) })

            select(Row(_, _, _))
              |> field(p.id)
              |> field(p.name)
              |> field(o.total)
              |> where(p.age |> is_not_null)
              |> where(o.total |> eq(to_expr(100)))
          end


          def rendered -> (String, List(Value))
            query |> to_sql
          end
        JADE
      end

      it 'emits SELECT, FROM, INNER JOIN, WHERE clauses + params in order' do
        test_compiler.require('app', source)

        sql, params = App::Internal.rendered.then { [it._1, it._2] }

        expect(sql).to eql(
          'SELECT p.id, p.name, o.total ' \
          'FROM persons p ' \
          'INNER JOIN orders o ON p.id = o.person_id ' \
          'WHERE p.age IS NOT NULL AND o.total = ?'
        )
        expect(params).to eql [100]
      end
    end

    describe 'order and group for sorting and grouping' do
      let(:source) do
        <<~JADE
          module App exposing (
            grouped,
            multi_sorted,
            sorted_asc,
            sorted_desc,
            sorted_then_paged,
          )

          import Sql exposing (Expr, Selector, Table, column, table)
          import Sql.Query exposing (
            Q,
            field,
            from,
            group,
            limit,
            offset,
            order,
            order_desc,
            select,
            to_sql,
          )
          import Decode exposing (Value)


          struct PersonsCols = {
            id: Expr(Int),
            name: Expr(String),
            age: Expr(Int)
          }


          struct MaybePersonsCols = {
            id: Expr(Maybe(Int)),
            name: Expr(Maybe(String)),
            age: Expr(Maybe(Int))
          }


          struct Person = {
            id: Int,
            name: String,
            age: Int
          }


          def persons -> Table(PersonsCols, MaybePersonsCols)
            table(
              "persons",
              "p",
              (a) -> { PersonsCols(column(a, "id"), column(a, "name"), column(a, "age")) },
              (a) -> { MaybePersonsCols(
                column(a, "id"),
                column(a, "name"),
                column(a, "age"),
              ) },
              ["id"],
            )
          end


          def projected -> Q(Selector(Person))
            p <- from(persons)

            select(Person(_, _, _))
              |> field(p.id)
              |> field(p.name)
              |> field(p.age)
          end


          def sorted_asc_q -> Q(Selector(Person))
            p <- from(persons)

            select(Person(_, _, _))
              |> field(p.id)
              |> field(p.name)
              |> field(p.age)
              |> order(p.name)
          end


          def sorted_desc_q -> Q(Selector(Person))
            p <- from(persons)

            select(Person(_, _, _))
              |> field(p.id)
              |> field(p.name)
              |> field(p.age)
              |> order_desc(p.age)
          end


          def multi_sorted_q -> Q(Selector(Person))
            p <- from(persons)

            select(Person(_, _, _))
              |> field(p.id)
              |> field(p.name)
              |> field(p.age)
              |> order_desc(p.age)
              |> order(p.name)
          end


          def grouped_q -> Q(Selector(Person))
            p <- from(persons)

            select(Person(_, _, _))
              |> field(p.id)
              |> field(p.name)
              |> field(p.age)
              |> group(p.age)
              |> group(p.name)
          end


          def sorted_asc -> (String, List(Value))
            sorted_asc_q |> to_sql
          end


          def sorted_desc -> (String, List(Value))
            sorted_desc_q |> to_sql
          end


          def multi_sorted -> (String, List(Value))
            multi_sorted_q |> to_sql
          end


          def grouped -> (String, List(Value))
            grouped_q |> to_sql
          end


          def sorted_then_paged -> (String, List(Value))
            projected
              |> order_desc(column("p", "id"))
              |> limit(10)
              |> offset(20)
              |> to_sql
          end
        JADE
      end

      before { test_compiler.require('app', source) }

      it 'appends ORDER BY with implicit ASC' do
        sql, _ = App::Internal.sorted_asc.then { [it._1, it._2] }
        expect(sql).to eql(
          'SELECT p.id, p.name, p.age FROM persons p ORDER BY p.name'
        )
      end

      it 'appends ORDER BY ... DESC' do
        sql, _ = App::Internal.sorted_desc.then { [it._1, it._2] }
        expect(sql).to eql(
          'SELECT p.id, p.name, p.age FROM persons p ORDER BY p.age DESC'
        )
      end

      it 'preserves order-by declaration order across mixed directions' do
        sql, _ = App::Internal.multi_sorted.then { [it._1, it._2] }
        expect(sql).to eql(
          'SELECT p.id, p.name, p.age FROM persons p ORDER BY p.age DESC, p.name'
        )
      end

      it 'appends GROUP BY with comma-separated columns' do
        sql, _ = App::Internal.grouped.then { [it._1, it._2] }
        expect(sql).to eql(
          'SELECT p.id, p.name, p.age FROM persons p GROUP BY p.age, p.name'
        )
      end

      it 'renders ORDER BY before LIMIT/OFFSET' do
        sql, _ = App::Internal.sorted_then_paged.then { [it._1, it._2] }
        expect(sql).to eql(
          'SELECT p.id, p.name, p.age ' \
          'FROM persons p ' \
          'ORDER BY p.id DESC ' \
          'LIMIT 10 OFFSET 20'
        )
      end
    end

    describe 'limit and offset for pagination' do
      let(:source) do
        <<~JADE
          module App exposing (no_paging, only_offset, page_one, page_two)

          import Sql exposing (Expr, Selector, Table, column, table)
          import Sql.Query exposing (Q, field, from, limit, offset, select, to_sql)
          import Decode exposing (Value)


          struct PersonsCols = {
            id: Expr(Int),
            name: Expr(String)
          }


          struct MaybePersonsCols = {
            id: Expr(Maybe(Int)),
            name: Expr(Maybe(String))
          }


          struct Person = {
            id: Int,
            name: String
          }


          def persons -> Table(PersonsCols, MaybePersonsCols)
            table(
              "persons",
              "p",
              (a) -> { PersonsCols(column(a, "id"), column(a, "name")) },
              (a) -> { MaybePersonsCols(column(a, "id"), column(a, "name")) },
              ["id"],
            )
          end


          def projected -> Q(Selector(Person))
            p <- from(persons)

            select(Person(_, _))
              |> field(p.id)
              |> field(p.name)
          end


          def page_one -> (String, List(Value))
            projected
              |> limit(10)
              |> to_sql
          end


          def page_two -> (String, List(Value))
            projected
              |> limit(10)
              |> offset(10)
              |> to_sql
          end


          def only_offset -> (String, List(Value))
            projected
              |> offset(20)
              |> to_sql
          end


          def no_paging -> (String, List(Value))
            projected |> to_sql
          end
        JADE
      end

      before { test_compiler.require('app', source) }

      it 'appends LIMIT after WHERE' do
        sql, params = App::Internal.page_one.then { [it._1, it._2] }
        expect(sql).to eql 'SELECT p.id, p.name FROM persons p LIMIT 10'
        expect(params).to eql []
      end

      it 'appends LIMIT then OFFSET' do
        sql, params = App::Internal.page_two.then { [it._1, it._2] }
        expect(sql).to eql 'SELECT p.id, p.name FROM persons p LIMIT 10 OFFSET 10'
        expect(params).to eql []
      end

      it 'appends only OFFSET when LIMIT is unset' do
        sql, _ = App::Internal.only_offset.then { [it._1, it._2] }
        expect(sql).to eql 'SELECT p.id, p.name FROM persons p OFFSET 20'
      end

      it 'emits no LIMIT/OFFSET when neither is set' do
        sql, _ = App::Internal.no_paging.then { [it._1, it._2] }
        expect(sql).to eql 'SELECT p.id, p.name FROM persons p'
      end
    end

    describe 'codec-driven mutations' do
      let(:source) do
        <<~JADE
          module App exposing (
            delete_archived,
            delete_paul,
            delete_paul_returning,
            insert_from_assigns,
            insert_many,
            insert_paul,
            insert_paul_returning,
            update_all_to_zero,
            update_paul,
            update_paul_returning,
          )

          import Sql exposing (
            Assignment(..),
            Expr,
            Identified,
            Selector,
            SqlMapper,
            Table,
            assign,
            column,
            eq,
            pk_values,
            set_,
            table,
            to_assigns,
            to_expr,
          )
          import Sql.Query exposing (Q, field, select)
          import Sql.Mutation exposing (
            Mutation,
            delete,
            delete_all,
            insert,
            insert_all,
            returning,
            to_sql,
            update,
            update_all,
          )
          import Decode exposing (Value)
          import Encode exposing (encode)


          struct PatientsCols = {
            id: Expr(Int),
            name: Expr(String),
            balance: Expr(Int),
            archived: Expr(Bool)
          }


          struct MaybePatientsCols = {
            id: Expr(Maybe(Int)),
            name: Expr(Maybe(String)),
            balance: Expr(Maybe(Int)),
            archived: Expr(Maybe(Bool))
          }


          struct Patient = {
            id: Int,
            name: String,
            balance: Int
          }


          def patients -> Table(PatientsCols, MaybePatientsCols)
            table(
              "patients",
              "p",
              (a) -> { PatientsCols(
                column(a, "id"),
                column(a, "name"),
                column(a, "balance"),
                column(a, "archived"),
              ) },
              (a) -> { MaybePatientsCols(
                column(a, "id"),
                column(a, "name"),
                column(a, "balance"),
                column(a, "archived"),
              ) },
              ["id"],
            )
          end


          implements SqlMapper(Patient) with
            to_assigns: encode_patient
          end


          implements Identified(Patient) with
            pk_values: encode_patient_pk
          end


          def encode_patient(p: Patient) -> List(Assignment)
            [
              assign("name", p.name),
              assign("balance", p.balance),
            ]
          end


          def encode_patient_pk(p: Patient) -> List(Value)
            [encode(p.id)]
          end


          def insert_paul -> (String, List(Value))
            Patient(0, "Paul", 100)
              |> insert(patients)
              |> to_sql
          end


          def insert_from_assigns -> (String, List(Value))
            [assign("name", "Paul"), assign("balance", 100)]
              |> insert(patients)
              |> to_sql
          end


          def update_paul -> (String, List(Value))
            Patient(42, "Paul", 100)
              |> update(patients)
              |> to_sql
          end


          def delete_paul -> (String, List(Value))
            Patient(42, "Paul", 100)
              |> delete(patients)
              |> to_sql
          end


          def insert_many -> (String, List(Value))
            [Patient(0, "Paul", 100), Patient(0, "Frank", 200)]
              |> insert_all(patients)
              |> to_sql
          end


          def update_all_to_zero -> (String, List(Value))
            patients
              |> update_all(
            (p) -> { p.balance |> eq(to_expr(0)) },
            (p) -> { [p.archived |> set_(to_expr(True))] },
          )
              |> to_sql
          end


          def delete_archived -> (String, List(Value))
            patients
              |> delete_all((p) -> { p.archived |> eq(to_expr(True)) })
              |> to_sql
          end


          def insert_paul_returning -> (String, List(Value))
            Patient(0, "Paul", 100)
              |> insert(patients)
              |> returning(
            (p) -> { select(Patient(_, _, _))
              |> field(p.id)
              |> field(p.name)
              |> field(p.balance) },
          )
              |> to_sql
          end


          def update_paul_returning -> (String, List(Value))
            Patient(42, "Paul", 100)
              |> update(patients)
              |> returning(
            (p) -> { select(Patient(_, _, _))
              |> field(p.id)
              |> field(p.name)
              |> field(p.balance) },
          )
              |> to_sql
          end


          def delete_paul_returning -> (String, List(Value))
            Patient(42, "Paul", 100)
              |> delete(patients)
              |> returning(
            (p) -> { select(Patient(_, _, _))
              |> field(p.id)
              |> field(p.name)
              |> field(p.balance) },
          )
              |> to_sql
          end
        JADE
      end

      before { test_compiler.require('app', source) }

      it 'insert renders INSERT with codec-driven assigns' do
        sql, params = App::Internal.insert_paul.then { [it._1, it._2] }
        expect(sql).to eql 'INSERT INTO patients (name, balance) VALUES (?, ?)'
        expect(params).to eql ['Paul', 100]
      end

      it 'insert accepts a raw List(Assignment) via SqlMapper(List(Assignment))' do
        sql, params = App::Internal.insert_from_assigns.then { [it._1, it._2] }
        expect(sql).to eql 'INSERT INTO patients (name, balance) VALUES (?, ?)'
        expect(params).to eql ['Paul', 100]
      end

      it 'update renders UPDATE … WHERE pk = ?' do
        sql, params = App::Internal.update_paul.then { [it._1, it._2] }
        expect(sql).to eql 'UPDATE patients SET name = ?, balance = ? WHERE id = ?'
        expect(params).to eql ['Paul', 100, 42]
      end

      it 'delete renders DELETE … WHERE pk = ?' do
        sql, params = App::Internal.delete_paul.then { [it._1, it._2] }
        expect(sql).to eql 'DELETE FROM patients WHERE id = ?'
        expect(params).to eql [42]
      end

      it 'insert_all renders multi-row VALUES' do
        sql, params = App::Internal.insert_many.then { [it._1, it._2] }
        expect(sql).to eql 'INSERT INTO patients (name, balance) VALUES (?, ?), (?, ?)'
        expect(params).to eql [
          'Paul',  100,
          'Frank', 200
        ]
      end

      it 'update_all renders bulk UPDATE with predicate' do
        sql, params = App::Internal.update_all_to_zero.then { [it._1, it._2] }
        expect(sql).to eql 'UPDATE patients SET archived = ? WHERE balance = ?'
        expect(params).to eql [true, 0]
      end

      it 'delete_all renders bulk DELETE with predicate' do
        sql, params = App::Internal.delete_archived.then { [it._1, it._2] }
        expect(sql).to eql 'DELETE FROM patients WHERE archived = ?'
        expect(params).to eql [true]
      end

      it 'insert + returning projects the table columns into RETURNING' do
        sql, _ = App::Internal.insert_paul_returning.then { [it._1, it._2] }
        expect(sql).to eql 'INSERT INTO patients (name, balance) VALUES (?, ?) RETURNING id, name, balance'
      end

      it 'update + returning appends RETURNING with the projected columns' do
        sql, _ = App::Internal.update_paul_returning.then { [it._1, it._2] }
        expect(sql).to eql 'UPDATE patients SET name = ?, balance = ? WHERE id = ? RETURNING id, name, balance'
      end

      it 'delete + returning appends RETURNING with the projected columns' do
        sql, _ = App::Internal.delete_paul_returning.then { [it._1, it._2] }
        expect(sql).to eql 'DELETE FROM patients WHERE id = ? RETURNING id, name, balance'
      end
    end

  end
end

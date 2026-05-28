require 'spec_helper'

require 'jade'
require 'jade/module_loader'
require 'jade/tasks'
require 'jade/tasks/rspec'

# Load the extension (registers the source root) but NOT the runtime
# (which would require ActiveRecord). We stub the task dispatcher
# instead — the runtime body is never invoked.
require_relative '../../extensions/jade_sql/lib/jade-sql'

# Stub TaskDefs to stand in for the real JadeSql::Runtime ports.
module JadeSql
  module Runtime
    extend Jade::Port unless respond_to?(:task)

    task(:port_execute_count) { |t| t.err("unstubbed") }
    task(:port_execute_one)   { |t| t.err("unstubbed") }
    task(:port_execute_many)  { |t| t.err("unstubbed") }
  end
end

module Jade
  describe "Sql.fetch / execute" do
    include_context 'with test compiler'
    include Jade::Tasks::RSpec

    let(:source) do
      <<~JADE
        module App exposing (
          all_via_run,
          count_via_execute,
          find_via_run,
          list_via_execute,
          paul_via_run,
        )

        import Sql exposing (Expr, Selector, Table, column, eq, table, to_expr)
        import Sql.Query exposing (Q, field, from, select, where)
        import Decode exposing (Value)
        import Encode
        import Sql exposing (
          SqlError,
          execute,
          execute_raw,
          fetch_many,
          fetch_many_raw,
          fetch_one,
          fetch_one_raw,
        )


        struct Patient = {
          id: Int,
          name: String,
          balance: Int
        }


        struct PatientsCols = {
          id: Expr(Int),
          name: Expr(String),
          balance: Expr(Int)
        }


        struct MaybePatientsCols = {
          id: Expr(Maybe(Int)),
          name: Expr(Maybe(String)),
          balance: Expr(Maybe(Int))
        }


        def patients -> Table(PatientsCols, MaybePatientsCols)
          table(
            "patients",
            "patients",
            (a) -> { PatientsCols(column(a, "id"), column(a, "name"), column(a, "balance")) },
            (a) -> { MaybePatientsCols(column(a, "id"), column(a, "name"), column(a, "balance")) },
            ["id"],
          )
        end


        def count_via_execute -> Task(Int, SqlError)
          execute_raw(("SELECT COUNT(*) FROM patients", []))
        end


        def list_via_execute -> Task(List(Patient), SqlError)
          fetch_many_raw(("SELECT * FROM patients", []))
        end


        def find_via_run -> Task(Patient, SqlError)
          fetch_one_raw(
            ("SELECT * FROM patients WHERE name = ?", [Encode.encode("Paul")]),
          )
        end


        def all_via_run -> Task(List(Patient), SqlError)
          fetch_many_raw(("SELECT * FROM patients", []))
        end


        def paul_query -> Q(Selector(Patient))
          p <- from(patients)

          select(Patient(_, _, _))
            |> field(p.id)
            |> field(p.name)
            |> field(p.balance)
            |> where(p.name |> eq(to_expr("Paul")))
        end


        def paul_via_run -> Task(Patient, SqlError)
          paul_query |> fetch_one
        end
      JADE
    end

    before { test_compiler.require('app', source) }

    describe "execute (alias for run_count over Renderable)" do
      it 'returns the affected count from the port' do
        all_calls_to(JadeSql::Runtime.port_execute_count) { |t, _pair| t.ok(7) }

        expect(App::Internal.count_via_execute.run).to be_ok(7)
        expect(JadeSql::Runtime.port_execute_count).to have_been_called
      end

      it 'surfaces a DbError from the port' do
        all_calls_to(JadeSql::Runtime.port_execute_count) do |t, _pair|
          t.err(JadeSql::SqlErrors.db_error("syntax error"))
        end

        expect(App::Internal.count_via_execute.run).to be_err(look_like("Sql::DbError", "syntax error"))
      end

      it 'surfaces a NotFound from port_execute_one' do
        all_calls_to(JadeSql::Runtime.port_execute_one) do |t, _pair|
          t.err(JadeSql::SqlErrors.not_found)
        end

        expect(App::Internal.find_via_run.run).to be_err(look_like("Sql::NotFound"))
      end

      it 'surfaces a NotUnique from port_execute_one' do
        all_calls_to(JadeSql::Runtime.port_execute_one) do |t, _pair|
          t.err(JadeSql::SqlErrors.not_unique)
        end

        expect(App::Internal.find_via_run.run).to be_err(look_like("Sql::NotUnique"))
      end
    end

    describe 'execute_one' do
      it 'decodes a single row into the caller-side struct' do
        all_calls_to(JadeSql::Runtime.port_execute_one) do |t, _pair|
          t.ok({ "id" => 1, "name" => "Paul", "balance" => 100 })
        end

        result = App::Internal.find_via_run.run
        expect(result).to be_ok(look_like("App::Patient", id: 1, name: "Paul", balance: 100))
      end
    end

    describe 'execute_many' do
      it 'decodes each row into the caller-side struct' do
        all_calls_to(JadeSql::Runtime.port_execute_many) do |t, _pair|
          t.ok([
            { "id" => 1, "name" => "Paul",  "balance" => 100 },
            { "id" => 2, "name" => "Frank", "balance" => 200 }
          ])
        end

        result = App::Internal.all_via_run.run
        expect(result).to be_ok
        expect(result._1.length).to eql 2
      end

      it 'returns an empty list when the DB returns no rows' do
        all_calls_to(JadeSql::Runtime.port_execute_many) { |t, _pair| t.ok([]) }

        result = App::Internal.list_via_execute.run
        expect(result).to be_ok
        expect(result._1).to eql []
      end
    end

    describe 'fetch_one via Renderable (Q)' do
      it 'renders the Q via to_sql and decodes the row' do
        all_calls_to(JadeSql::Runtime.port_execute_one) do |t, pair|
          # Verify Q.to_sql rendered the query the way we expect.
          sql, _params = pair._1, pair._2
          expect(sql).to include('SELECT patients.id, patients.name, patients.balance')
          expect(sql).to include('FROM patients patients')
          expect(sql).to include('WHERE patients.name = ?')

          t.ok({ "id" => 1, "name" => "Paul", "balance" => 100 })
        end

        result = App::Internal.paul_via_run.run
        expect(result).to be_ok(look_like("App::Patient", id: 1, name: "Paul", balance: 100))
      end
    end

    describe 'public boundary wrappers for Task(_, SqlError)' do
      it 'exposes App.fn returning ["ok", v] on success' do
        all_calls_to(JadeSql::Runtime.port_execute_count) { |t, _pair| t.ok(7) }

        expect(App.count_via_execute).to eql ["ok", 7]
      end

      it 'exposes App.fn returning ["err", ["DbError", msg]] on failure' do
        all_calls_to(JadeSql::Runtime.port_execute_count) do |t, _pair|
          t.err(JadeSql::SqlErrors.db_error("syntax error"))
        end

        expect(App.count_via_execute).to eql ["err", ["DbError", "syntax error"]]
      end

      it 'exposes ["err", ["NotFound"]] for a NotFound from port_execute_one' do
        all_calls_to(JadeSql::Runtime.port_execute_one) do |t, _pair|
          t.err(JadeSql::SqlErrors.not_found)
        end

        expect(App.find_via_run).to eql ["err", ["NotFound"]]
      end

      it 'exposes ["err", ["NotUnique"]] for a NotUnique from port_execute_one' do
        all_calls_to(JadeSql::Runtime.port_execute_one) do |t, _pair|
          t.err(JadeSql::SqlErrors.not_unique)
        end

        expect(App.find_via_run).to eql ["err", ["NotUnique"]]
      end

      it 'App.fn! returns the value on success' do
        all_calls_to(JadeSql::Runtime.port_execute_count) { |t, _pair| t.ok(7) }

        expect(App.count_via_execute!).to eql 7
      end

      it 'App.fn! raises Jade::Interop::TaskError on failure' do
        all_calls_to(JadeSql::Runtime.port_execute_count) do |t, _pair|
          t.err(JadeSql::SqlErrors.db_error("syntax error"))
        end

        expect { App.count_via_execute! }.to raise_error(Jade::Interop::TaskError)
      end
    end
  end

  describe 'Sql.raise_typed!' do
    it 'raises Sql::Errors::DbError for ["DbError", msg]' do
      expect { Sql.raise_typed!(["DbError", "syntax error"]) }
        .to raise_error(Sql::Errors::DbError, "syntax error")
    end

    it 'raises Sql::Errors::NotFound for ["NotFound"]' do
      expect { Sql.raise_typed!(["NotFound"]) }
        .to raise_error(Sql::Errors::NotFound)
    end

    it 'raises Sql::Errors::NotUnique for ["NotUnique"]' do
      expect { Sql.raise_typed!(["NotUnique"]) }
        .to raise_error(Sql::Errors::NotUnique)
    end

    it 'falls back to Sql::Errors::Error for an unknown type' do
      expect { Sql.raise_typed!(["Unknown", "x"]) }
        .to raise_error(Sql::Errors::Error, "x")
    end

    it 'DbError, NotFound, NotUnique are all subclasses of Sql::Errors::Error' do
      expect(Sql::Errors::DbError.ancestors).to include(Sql::Errors::Error)
      expect(Sql::Errors::NotFound.ancestors).to include(Sql::Errors::Error)
      expect(Sql::Errors::NotUnique.ancestors).to include(Sql::Errors::Error)
    end
  end
end

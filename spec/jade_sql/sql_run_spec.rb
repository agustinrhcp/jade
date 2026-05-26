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
  describe 'Sql.Run' do
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
        import Sql.Run exposing (
          SqlError,
          execute_count,
          execute_many,
          execute_one,
          run_count,
          run_many,
          run_one,
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


        def count_via_execute -> Task(Int, SqlError)
          execute_count(("SELECT COUNT(*) FROM patients", []))


        def list_via_execute -> Task(List(Patient), SqlError)
          execute_many(("SELECT * FROM patients", []))


        def find_via_run -> Task(Patient, SqlError)
          execute_one(
            ("SELECT * FROM patients WHERE name = ?", [Encode.encode("Paul")]),
          )


        def all_via_run -> Task(List(Patient), SqlError)
          execute_many(("SELECT * FROM patients", []))


        def paul_query -> Q(Selector(Patient))
          p <- from(patients)

          select(Patient(_, _, _))
            |> field(p.id)
            |> field(p.name)
            |> field(p.balance)
            |> where(p.name |> eq(to_expr("Paul")))


        def paul_via_run -> Task(Patient, SqlError)
          paul_query |> run_one
      JADE
    end

    before { test_compiler.require('app', source) }

    describe 'execute_count' do
      it 'returns the affected count from the port' do
        all_calls_to(JadeSql::Runtime.port_execute_count) { |t, _pair| t.ok(7) }

        expect(App::Internal.count_via_execute.run).to be_ok(7)
        expect(JadeSql::Runtime.port_execute_count).to have_been_called
      end

      it 'surfaces a DbError from the port' do
        all_calls_to(JadeSql::Runtime.port_execute_count) do |t, _pair|
          t.err(JadeSql::SqlErrors.db_error("syntax error"))
        end

        expect(App::Internal.count_via_execute.run).to be_err(look_like("Sql::Run::DbError", "syntax error"))
      end

      it 'surfaces a NotFound from port_execute_one' do
        all_calls_to(JadeSql::Runtime.port_execute_one) do |t, _pair|
          t.err(JadeSql::SqlErrors.not_found)
        end

        expect(App::Internal.find_via_run.run).to be_err(look_like("Sql::Run::NotFound"))
      end

      it 'surfaces a NotUnique from port_execute_one' do
        all_calls_to(JadeSql::Runtime.port_execute_one) do |t, _pair|
          t.err(JadeSql::SqlErrors.not_unique)
        end

        expect(App::Internal.find_via_run.run).to be_err(look_like("Sql::Run::NotUnique"))
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

    describe 'run_one via Renderable (Q)' do
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

  describe 'Sql::Run.raise_typed!' do
    it 'raises Sql::Run::Errors::DbError for ["DbError", msg]' do
      expect { Sql::Run.raise_typed!(["DbError", "syntax error"]) }
        .to raise_error(Sql::Run::Errors::DbError, "syntax error")
    end

    it 'raises Sql::Run::Errors::NotFound for ["NotFound"]' do
      expect { Sql::Run.raise_typed!(["NotFound"]) }
        .to raise_error(Sql::Run::Errors::NotFound)
    end

    it 'raises Sql::Run::Errors::NotUnique for ["NotUnique"]' do
      expect { Sql::Run.raise_typed!(["NotUnique"]) }
        .to raise_error(Sql::Run::Errors::NotUnique)
    end

    it 'falls back to Sql::Run::Errors::Error for an unknown type' do
      expect { Sql::Run.raise_typed!(["Unknown", "x"]) }
        .to raise_error(Sql::Run::Errors::Error, "x")
    end

    it 'DbError, NotFound, NotUnique are all subclasses of Sql::Run::Errors::Error' do
      expect(Sql::Run::Errors::DbError.ancestors).to include(Sql::Run::Errors::Error)
      expect(Sql::Run::Errors::NotFound.ancestors).to include(Sql::Run::Errors::Error)
      expect(Sql::Run::Errors::NotUnique.ancestors).to include(Sql::Run::Errors::Error)
    end
  end
end

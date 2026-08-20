require 'spec_helper'

require 'jade'
require 'jade/module_loader'

module Jade
  describe 'checking a written struct against its table' do
    include_context 'with test compiler'

    # Stands in for jade-sql, which jade does not depend on. The check assumes
    # exactly these shapes, so this is also where that coupling is written down.
    let(:sql_source) do
      <<~JADE.strip
        module Sql exposing (Assignment(..), Expr(..), Pk(..), Table(..), column, table)

        import Decode exposing (Value)


        struct Expr(a) = { sql: String }


        struct Assignment = {
          col: String,
          value_sql: String,
          params: List(Value)
        }


        struct Pk(c, k) = { columns: List(String) }


        struct Table(c, m, k) = {
          name: String,
          cols: String -> c,
          pk: Pk(c, k)
        }


        def column(alias_: String, name: String) -> Expr(a)
          Expr(alias_ ++ "." ++ name)
        end


        def table(name: String, cols: String -> c, pk_: Pk(c, k)) -> Table(c, m, k)
          Table(name, cols, pk_)
        end
      JADE
    end

    let(:mutation_source) do
      <<~JADE.strip
        module Sql.Mutation exposing (insert, insert_all, update)

        import Sql exposing (Table)


        def insert(value: a, t: Table(c, m, k)) -> String
          t.name
        end


        def insert_all(values: List(a), t: Table(c, m, k)) -> String
          t.name
        end


        def update(value: a, t: Table(c, m, k), key: k) -> String
          t.name
        end
      JADE
    end

    def app(struct_fields, call)
      <<~JADE.strip
        module App exposing (go)

        import Sql exposing (Expr, Pk(..), Table, column, table)
        import Sql.Mutation exposing (insert, insert_all, update)


        struct PatientsCols = {
          id: Expr(Int),
          name: Expr(String),
          balance: Expr(Maybe(Int))
        }


        struct Patient = {
        #{struct_fields}
        }


        def patients -> Table(PatientsCols, PatientsCols, Int)
          table(
            "patients",
            (a) -> { PatientsCols(column(a, "id"), column(a, "name"), column(a, "balance")) },
            Pk(["id"]),
          )
        end


        def go -> String
          #{call}
        end
      JADE
    end

    before do
      test_compiler.require(sql_source)
      test_compiler.require(mutation_source)
    end

    let(:good_fields) { "  name: String,\n  balance: Maybe(Int)" }
    let(:bad_fields) { "  nmae: String,\n  balance: Maybe(Int)" }
    let(:mistyped_fields) { "  name: Int,\n  balance: Maybe(Int)" }

    it 'accepts a struct whose fields are all columns of the table' do
      expect { test_compiler.require(app(good_fields, 'insert(Patient("Ada", Just(1)), patients)')) }
        .not_to raise_error
    end

    it 'names the field the table has no column for' do
      expect { test_compiler.require(app(bad_fields, 'insert(Patient("Ada", Just(1)), patients)')) }
        .to raise_error(/Patient\.nmae has no column on PatientsCols/)
    end

    it 'reports a field whose type is not the column type' do
      expect { test_compiler.require(app(mistyped_fields, 'insert(Patient(1, Just(1)), patients)')) }
        .to raise_error(/name is String, but Patient\.name is Int/)
    end

    it 'checks the element type of insert_all' do
      expect { test_compiler.require(app(bad_fields, 'insert_all([Patient("Ada", Just(1))], patients)')) }
        .to raise_error(/nmae has no column/)
    end

    it 'checks update the same way, past the key argument' do
      expect { test_compiler.require(app(bad_fields, 'update(Patient("Ada", Just(1)), patients, 1)')) }
        .to raise_error(/nmae has no column/)
    end

    context 'a column renamed to dodge a jade keyword' do
      let(:reserved_app) do
        <<~JADE.strip
          module App exposing (go)

          import Sql exposing (Expr, Pk(..), Table, column, table)
          import Sql.Mutation exposing (insert)


          struct EntriesCols = { type_: Expr(String) }


          struct Entry = { type_: String }


          def entries -> Table(EntriesCols, EntriesCols, Int)
            table("entries", (a) -> { EntriesCols(column(a, "type")) }, Pk(["id"]))
          end


          def go -> String
            insert(Entry("debit"), entries)
          end
        JADE
      end

      it 'matches the field against the column it was renamed from' do
        expect { test_compiler.require(reserved_app) }.not_to raise_error
      end
    end

    context 'a generic helper wrapping insert' do
      let(:wrapped_app) do
        <<~JADE.strip
          module App exposing (go)

          import Sql exposing (Expr, Pk(..), Table, column, table)
          import Sql.Mutation exposing (insert)


          struct PatientsCols = { name: Expr(String) }


          struct Patient = { nmae: String }


          def patients -> Table(PatientsCols, PatientsCols, Int)
            table("patients", (a) -> { PatientsCols(column(a, "name")) }, Pk(["id"]))
          end


          def save(v: a, t: Table(c, m, k)) -> String
            insert(v, t)
          end


          def go -> String
            save(Patient("Ada"), patients)
          end
        JADE
      end

      # The check reads the types at the call it can see. Inside `save` both
      # are still variables, and at `save` the callee is not one of jade-sql's
      # entry points — so wrapping opts out, quietly and by design.
      it 'stays quiet, since neither call site has both types' do
        expect { test_compiler.require(wrapped_app) }.not_to raise_error
      end
    end
  end
end

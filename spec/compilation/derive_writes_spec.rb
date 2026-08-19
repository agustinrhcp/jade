require 'spec_helper'

require 'jade'
require 'jade/module_loader'

module Jade
  describe 'deriving Assignable for Writes' do
    include_context 'with test compiler'

    let(:sql_source) do
      <<~JADE.strip
        module Sql exposing (
          Assignable,
          Assignment(..),
          Expr(..),
          Table(..),
          Writes(..),
          insert,
          to_assigns,
        )

        import Decode exposing (Value)


        struct Expr(a) = { sql: String }


        struct Assignment = {
          col: String,
          value_sql: String,
          params: List(Value)
        }


        struct Writes(c, a) = { value: a }


        struct Table(c, m) = { name: String }


        interface Assignable(w) with
          to_assigns : w -> List(Assignment)
        end


        def insert(v: a, t: Table(c, m)) -> List(Assignment)
          to_assigns(writes_for(t, v))
        end


        def writes_for(t: Table(c, m), v: a) -> Writes(c, a)
          Writes(v)
        end
      JADE
    end

    let(:app_source) do
      <<~JADE.strip
        module App exposing (go)

        import Sql exposing (Assignment, Expr, Table(..), insert)


        struct ProductsCols = {
          id: Expr(Int),
          name: Expr(String)
        }


        struct NewProduct = { name: String }


        def products -> Table(ProductsCols, ProductsCols)
          Table("products")
        end


        def go -> List(Assignment)
          NewProduct("Widget") |> insert(products)
        end
      JADE
    end

    before do
      test_compiler.require(sql_source)
      test_compiler.require(app_source) unless compile_fails
    end

    let(:compile_fails) { false }

    it 'assigns the value struct against the table it is headed for' do
      expect(App::Internal.go)
        .to eql [Sql::Assignment['name', '?', ['Widget']]]
    end

    context 'a caller that is itself polymorphic' do
      let(:app_source) do
        <<~JADE.strip
          module App exposing (go)

          import Sql exposing (Assignment, Expr, Table(..), insert)


          struct ProductsCols = {
            id: Expr(Int),
            name: Expr(String)
          }


          struct NewProduct = { name: String }


          def products -> Table(ProductsCols, ProductsCols)
            Table("products")
          end


          def assigns_for(v: a, t: Table(c, m)) -> List(Assignment)
            insert(v, t)
          end


          def go -> List(Assignment)
            NewProduct("Widget") |> assigns_for(products)
          end
        JADE
      end

      it 'takes the dictionary itself and passes it down' do
        expect(App::Internal.go)
          .to eql [Sql::Assignment['name', '?', ['Widget']]]
      end
    end

    context 'a field with no column of that name' do
      let(:app_source) do
        <<~JADE.strip
          module App exposing (go)

          import Sql exposing (Assignment, Expr, Table(..), insert)


          struct ProductsCols = { id: Expr(Int) }


          struct NewProduct = { name: String }


          def products -> Table(ProductsCols, ProductsCols)
            Table("products")
          end


          def go -> List(Assignment)
            NewProduct("Widget") |> insert(products)
          end
        JADE
      end

      let(:compile_fails) { true }

      it 'fails at the call site, naming the field' do
        expect { test_compiler.require(app_source) }
          .to raise_error(CompilationError, /no column `name`/)
      end
    end
  end
end

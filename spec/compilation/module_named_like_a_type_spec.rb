require 'spec_helper'

require 'jade'
require 'jade/module_loader'

module Jade
  # A module and a type of the same name land on one Ruby constant. The
  # module reopens the type's class rather than defining a module beside
  # it, which used to leave whichever loaded second holding the name.
  describe 'a module named after a type in its parent' do
    include_context 'with test compiler'

    let(:parent) do
      <<~JADE
        module Q exposing (Expr(..), sql)

        struct Expr = { sql: String }


        def sql(e: Expr) -> String
          e.sql
        end
      JADE
    end

    let(:child) do
      <<~JADE
        module Q.Expr exposing (blank, eq)

        import Q exposing (Expr(..), sql)


        def eq(left: String, right: String) -> String
          left ++ " = " ++ right
        end


        def blank -> String
          sql(Expr(""))
        end
      JADE
    end

    before do
      test_compiler.write(parent)
      test_compiler.require(child)
    end

    it 'keeps the module functions' do
      expect(Q::Expr.eq("a", "b")).to eq 'a = b'
    end

    it 'keeps the constructor' do
      expect(Q::Expr['x']).to have_attributes(sql: 'x')
    end

    it 'lets the module build and read the type it is named after' do
      expect(Q::Expr.blank).to eq ''
    end

    it 'still pattern matches' do
      matched = case Q::Expr['x']
                in Q::Expr[sql] then sql
                end

      expect(matched).to eq 'x'
    end
  end
end

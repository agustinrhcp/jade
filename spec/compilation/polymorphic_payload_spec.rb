require 'spec_helper'

require 'jade'
require 'jade/module_loader'

module Jade
  describe 'polymorphic generics in struct/variant payloads' do
    include_context 'with test compiler'

    context 'union with function-typed variants over a type param' do
      let(:source) do
        <<~JADE
          module Filters exposing (Filter, empty)

          type Expr(a) = E(a)


          type Filter(c)
            = DateF(String, (c, Int) -> Expr(Bool))
            | IntF(String, (c, Int) -> Expr(Bool))


          def empty -> List(Filter(c))
            []
          end
        JADE
      end

      it 'compiles' do
        expect { test_compiler.require('filters', source) }.not_to raise_error
      end
    end

    context 'empty list in a case-of arm of a polymorphic-return function' do
      let(:source) do
        <<~JADE
          module M exposing (lookup_or_empty)

          def lookup_or_empty(m: Maybe(List(a))) -> List(a)
            case m
            in Just(items) then items
            in Nothing then []
            end
          end
        JADE
      end

      it 'compiles' do
        expect { test_compiler.require('m', source) }.not_to raise_error
      end
    end
  end
end

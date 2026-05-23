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
        JADE
      end

      it 'compiles' do
        expect { test_compiler.require('filters', source) }.not_to raise_error
      end
    end
  end
end

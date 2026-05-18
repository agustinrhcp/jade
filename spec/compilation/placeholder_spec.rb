require 'spec_helper'

require 'jade'
require 'jade/module_loader'

module Jade
  describe 'Placeholder (curried calls)' do
    include_context 'with test compiler'

    context 'partial application of a function' do
      before do
        test_compiler.require('hole_app', source)
      end

      let(:source) do
        <<~JADE
          module HoleApp exposing (add5, add5_left, curried_sum)

          def add(a: Int, b: Int) -> Int
            a + b
          end

          def add5(x: Int) -> Int
            add(_, 5)(x)
          end

          def add5_left(x: Int) -> Int
            add(5, _)(x)
          end

          def curried_sum(a: Int, b: Int) -> Int
            add(_, _)(a)(b)
          end
        JADE
      end

      it 'fills the trailing hole' do
        expect(HoleApp.add5(10)).to eql 15
      end

      it 'fills the leading hole' do
        expect(HoleApp.add5_left(10)).to eql 15
      end

      it 'curries when all args are holes' do
        expect(HoleApp.curried_sum(2, 3)).to eql 5
      end
    end

    context 'partial application of a constructor' do
      before do
        test_compiler.require('hole_ctor', source)
      end

      let(:source) do
        <<~JADE
          module HoleCtor exposing (build_first, just_holed)

          type Pair(a, b) = Pair(a, b)

          def just_holed(x: Int) -> Pair(Int, String)
            Pair(_, "fixed")(x)
          end

          def build_first(x: Int, y: String) -> Pair(Int, String)
            Pair(_, _)(x)(y)
          end
        JADE
      end

      it 'partially applies a constructor with one hole' do
        result = HoleCtor::Internal.just_holed.call(7)
        expect(result.send(:_1)).to eql 7
        expect(result.send(:_2)).to eql "fixed"
      end

      it 'curries a 2-arg constructor' do
        result = HoleCtor::Internal.build_first.call(7, "ok")
        expect(result.send(:_1)).to eql 7
        expect(result.send(:_2)).to eql "ok"
      end
    end
  end
end

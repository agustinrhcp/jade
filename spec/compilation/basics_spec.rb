require 'spec_helper'

require 'jade'
require 'jade/module_loader'

module Jade
  describe 'Basics' do
    include_context 'with test compiler'

    describe 'Math' do
      before do
        test_compiler.require('math', math_source)
      end

      let(:math_source) do
        <<~JADE
          module Math exposing (example1, example2)

          def example1() -> Int
            pepe = Just(1)

            1 + 2 * 3
          end

          def example2() -> Int
            (1 + 2) * 3
          end
        JADE
      end

      it 'respect operator precedence and grouping' do
        expect(Math.example1.call).to eql 7
        expect(Math.example2.call).to eql 9
      end

      context 'float' do
        let(:math_source) do
          <<~JADE
            module Math exposing (floats)

            def floats() -> Float
              42.42
            end
          JADE
        end

        it 'returns a float' do
          expect(Math.floats.call).to eql 42.42
        end
      end

      context 'negative integer literal' do
        let(:math_source) do
          <<~JADE
            module Math exposing (neg_float, neg_int)

            def neg_int() -> Int
              -1
            end

            def neg_float() -> Float
              -3.14
            end
          JADE
        end

        it 'returns negative numbers' do
          expect(Math.neg_int.call).to eql(-1)
          expect(Math.neg_float.call).to eql(-3.14)
        end
      end

      context 'ruby keyword' do
        let(:math_source) do
          <<~JADE
            module Math exposing (negate)

            def negate(a: Bool) -> Bool
              not(a)
            end
          JADE
        end

        it 'returns the value negated' do
          expect(Math.negate.call(true)).to be false
          expect(Math.negate.call(false)).to be true
        end
      end
    end

    describe 'min and max' do
      before do
        test_compiler.require('cmp', source)
      end

      let(:source) do
        <<~JADE
          module Cmp exposing (max_float, max_int, min_float, min_int)

          def min_int(a: Int, b: Int) -> Int
            min(a, b)
          end

          def max_int(a: Int, b: Int) -> Int
            max(a, b)
          end

          def min_float(a: Float, b: Float) -> Float
            min(a, b)
          end

          def max_float(a: Float, b: Float) -> Float
            max(a, b)
          end
        JADE
      end

      it 'picks the smaller of two ints' do
        expect(Cmp.min_int.call(1, 2)).to eql 1
        expect(Cmp.min_int.call(2, 1)).to eql 1
        expect(Cmp.min_int.call(3, 3)).to eql 3
      end

      it 'picks the larger of two ints' do
        expect(Cmp.max_int.call(1, 2)).to eql 2
        expect(Cmp.max_int.call(2, 1)).to eql 2
        expect(Cmp.max_int.call(3, 3)).to eql 3
      end

      it 'picks the smaller of two floats' do
        expect(Cmp.min_float.call(1.5, 2.5)).to eql 1.5
        expect(Cmp.min_float.call(2.5, 1.5)).to eql 1.5
      end

      it 'picks the larger of two floats' do
        expect(Cmp.max_float.call(1.5, 2.5)).to eql 2.5
        expect(Cmp.max_float.call(2.5, 1.5)).to eql 2.5
      end
    end
  end
end

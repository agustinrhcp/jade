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

          def example1 -> Int
            pepe = Just(1)
            1 + 2 * 3
          end


          def example2 -> Int
            (1 + 2) * 3
          end
        JADE
      end

      it 'respect operator precedence and grouping' do
        expect(Math.example1).to eql 7
        expect(Math.example2).to eql 9
      end

      context 'float' do
        let(:math_source) do
          <<~JADE
            module Math exposing (floats)

            def floats -> Float
              42.42
            end
          JADE
        end

        it 'returns a float' do
          expect(Math.floats).to eql 42.42
        end
      end

      context 'negative integer literal' do
        let(:math_source) do
          <<~JADE
            module Math exposing (neg_float, neg_int)

            def neg_int -> Int
              -1
            end


            def neg_float -> Float
              -3.14
            end
          JADE
        end

        it 'returns negative numbers' do
          expect(Math.neg_int).to eql(-1)
          expect(Math.neg_float).to eql(-3.14)
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
          expect(Math.negate(true)).to be false
          expect(Math.negate(false)).to be true
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
        expect(Cmp.min_int(1, 2)).to eql 1
        expect(Cmp.min_int(2, 1)).to eql 1
        expect(Cmp.min_int(3, 3)).to eql 3
      end

      it 'picks the larger of two ints' do
        expect(Cmp.max_int(1, 2)).to eql 2
        expect(Cmp.max_int(2, 1)).to eql 2
        expect(Cmp.max_int(3, 3)).to eql 3
      end

      it 'picks the smaller of two floats' do
        expect(Cmp.min_float(1.5, 2.5)).to eql 1.5
        expect(Cmp.min_float(2.5, 1.5)).to eql 1.5
      end

      it 'picks the larger of two floats' do
        expect(Cmp.max_float(1.5, 2.5)).to eql 2.5
        expect(Cmp.max_float(2.5, 1.5)).to eql 2.5
      end
    end

    describe 'numeric conversions' do
      before { test_compiler.require('conv', source) }

      let(:source) do
        <<~JADE
          module Conv exposing (as_float, ceil_, floor_, round_, trunc_)

          def as_float(n: Int) -> Float
            to_float(n)
          end


          def floor_(n: Float) -> Int
            floor(n)
          end


          def ceil_(n: Float) -> Int
            ceiling(n)
          end


          def round_(n: Float) -> Int
            round(n)
          end


          def trunc_(n: Float) -> Int
            truncate(n)
          end
        JADE
      end

      it 'lifts Int to Float' do
        expect(Conv.as_float(3)).to eql 3.0
      end

      it 'floors, ceilings, rounds, and truncates' do
        expect(Conv.floor_(1.7)).to eql 1
        expect(Conv.floor_(-1.2)).to eql(-2)
        expect(Conv.ceil_(1.2)).to eql 2
        expect(Conv.ceil_(-1.7)).to eql(-1)
        expect(Conv.round_(1.5)).to eql 2
        expect(Conv.round_(1.4)).to eql 1
        expect(Conv.trunc_(1.9)).to eql 1
        expect(Conv.trunc_(-1.9)).to eql(-1)
      end
    end
  end
end

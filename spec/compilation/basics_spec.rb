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
  end
end

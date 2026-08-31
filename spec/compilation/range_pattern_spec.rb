require 'spec_helper'

require 'jade'
require 'jade/module_loader'

module Jade
  describe 'Range patterns' do
    include_context 'with test compiler'

    before do
      test_compiler.require(source)
    end

    context 'a table that partitions Int' do
      let(:source) do
        <<~JADE
          module Ranges exposing (band)

          def band(age: Int) -> String
            case age
            in ..-1 then "unborn"
            in 0..2 then "infant"
            in 3..12 then "child"
            in 13.. then "adult"
            end
          end
        JADE
      end

      it 'includes both bounds' do
        expect(Ranges::Internal.band(0)).to eql 'infant'
        expect(Ranges::Internal.band(2)).to eql 'infant'
        expect(Ranges::Internal.band(3)).to eql 'child'
        expect(Ranges::Internal.band(12)).to eql 'child'
      end

      it 'runs the unbounded arms' do
        expect(Ranges::Internal.band(-1)).to eql 'unborn'
        expect(Ranges::Internal.band(-9999)).to eql 'unborn'
        expect(Ranges::Internal.band(13)).to eql 'adult'
        expect(Ranges::Internal.band(9999)).to eql 'adult'
      end
    end

    context 'mixed with literals' do
      let(:source) do
        <<~JADE
          module Ranges exposing (price)

          def price(qty: Int) -> Int
            case qty
            in ..0 then 0
            in 1 then 100
            in 2..9 then 90
            in 10.. then 80
            end
          end
        JADE
      end

      it 'prefers the earlier arm' do
        expect(Ranges::Internal.price(0)).to eql 0
        expect(Ranges::Internal.price(1)).to eql 100
        expect(Ranges::Internal.price(2)).to eql 90
        expect(Ranges::Internal.price(9)).to eql 90
        expect(Ranges::Internal.price(10)).to eql 80
      end
    end

    # A branch with its body on the next line has no `then` to stop at, so an
    # open range must not take the body's first line as its upper bound.
    context 'with the body on the next line' do
      let(:source) do
        <<~JADE
          module Ranges exposing (sign)

          def sign(n: Int) -> Int
            case n
            in ..-1
              low = 0 - 1
              low
            in 0 then 0
            in 1..
              high = 1
              high
            end
          end
        JADE
      end

      it 'keeps the body out of the range' do
        expect(Ranges::Internal.sign(-5)).to eql(-1)
        expect(Ranges::Internal.sign(0)).to eql 0
        expect(Ranges::Internal.sign(5)).to eql 1
      end
    end

    context 'mixing bare literals and ranges' do
      let(:source) do
        <<~JADE
          module Ranges exposing (pick)

          def pick(n: Int) -> Int
            case n
            in 0 then 10
            in ..-1 then 20
            in 1 then 30
            else 40
            end
          end
        JADE
      end

      it 'cuts the line at every bound, whatever named it' do
        expect(Ranges::Internal.pick(-1)).to eql 20
        expect(Ranges::Internal.pick(0)).to eql 10
        expect(Ranges::Internal.pick(1)).to eql 30
        expect(Ranges::Internal.pick(2)).to eql 40
      end
    end

    context 'inside a constructor' do
      let(:source) do
        <<~JADE
          module Ranges exposing (describe)

          def describe(m: Maybe(Int)) -> String
            case m
            in Just(..0) then "none"
            in Just(1..) then "some"
            in Nothing then "unknown"
            end
          end
        JADE
      end

      it 'splits the payload column' do
        expect(Ranges::Internal.describe(Maybe::Just[0])).to eql 'none'
        expect(Ranges::Internal.describe(Maybe::Just[1])).to eql 'some'
        expect(Ranges::Internal.describe(Maybe::Nothing[])).to eql 'unknown'
      end
    end
  end
end

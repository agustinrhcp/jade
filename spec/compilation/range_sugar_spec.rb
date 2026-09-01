require 'spec_helper'

require 'jade'
require 'jade/module_loader'

module Jade
  describe 'The .. operator' do
    include_context 'with test compiler'

    before do
      test_compiler.require(source)
    end

    let(:source) do
      <<~JADE
        module Sugar exposing (empty, holds?, made, offset, shifted, span, wide?)

        def span(low: Int, high: Int) -> Range(Int)
          low..high
        end


        def made(low: Int, high: Int) -> Range(Int)
          Range.between(low, high)
        end


        def empty -> Range(Int)
          Range.empty
        end


        def holds?(low: Int, high: Int, n: Int) -> Bool
          Range.contains?(low..high, n)
        end


        # `..` sits below `+` and `-`, so this is `0..(n - 1)`.
        def offset(n: Int) -> Range(Int)
          0..n - 1
        end


        def shifted(n: Int) -> Range(Int)
          1 + 1..n * 2
        end


        def wide?(low: Int, high: Int) -> Bool
          Range.bounded?(low..high)
        end
      JADE
    end

    let(:s) { Sugar::Internal }

    it 'builds the same value the named constructor does' do
      expect(s.span(1, 5)).to eql s.made(1, 5)
    end

    it 'reads a descending pair as empty, like between' do
      expect(s.span(5, 1)).to eql s.empty
    end

    it 'is usable inline' do
      expect(s.holds?(13, 19, 13)).to be true
      expect(s.holds?(13, 19, 20)).to be false
      expect(s.wide?(1, 5)).to be true
    end

    describe 'precedence' do
      it 'binds looser than + and -' do
        expect(s.offset(5)).to eql s.made(0, 4)
        expect(s.offset(0)).to eql s.empty
      end

      it 'takes the whole arithmetic expression on each side' do
        expect(s.shifted(5)).to eql s.made(2, 10)
      end
    end
  end
end

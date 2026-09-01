require 'spec_helper'

require 'jade'
require 'jade/module_loader'

module Jade
  describe 'Range' do
    include_context 'with test compiler'

    before do
      test_compiler.require(source)
    end

    let(:source) do
      <<~JADE
        module Ranges exposing (
          all,
          between,
          bounded?,
          empty,
          empty?,
          from,
          highest,
          holds?,
          lowest,
          overlaps?,
          pulled,
          shared,
          to,
        )

        import Range exposing (Range)


        def between(low: Int, high: Int) -> Range(Int)
          Range.between(low, high)
        end


        def from(low: Int) -> Range(Int)
          Range.from(low)
        end


        def to(high: Int) -> Range(Int)
          Range.to(high)
        end


        def empty -> Range(Int)
          Range.empty
        end


        def all -> Range(Int)
          Range.all
        end


        def holds?(range: Range(Int), n: Int) -> Bool
          Range.contains?(range, n)
        end


        def empty?(range: Range(Int)) -> Bool
          Range.empty?(range)
        end


        def bounded?(range: Range(Int)) -> Bool
          Range.bounded?(range)
        end


        def overlaps?(one: Range(Int), other: Range(Int)) -> Bool
          Range.overlaps?(one, other)
        end


        def shared(one: Range(Int), other: Range(Int)) -> Range(Int)
          Range.intersect(one, other)
        end


        def pulled(range: Range(Int), n: Int) -> Maybe(Int)
          Range.clamp(range, n)
        end


        def lowest(range: Range(Int)) -> Maybe(Int)
          Range.lower(range)
        end


        def highest(range: Range(Int)) -> Maybe(Int)
          Range.upper(range)
        end
      JADE
    end

    let(:r) { Ranges::Internal }
    let(:teens) { r.between(13, 19) }

    describe 'contains?' do
      it 'includes both bounds' do
        expect(r.holds?(teens, 13)).to be true
        expect(r.holds?(teens, 19)).to be true
        expect(r.holds?(teens, 12)).to be false
        expect(r.holds?(teens, 20)).to be false
      end

      it 'answers for the endless shapes' do
        expect(r.holds?(r.from(13), 13)).to be true
        expect(r.holds?(r.from(13), 12)).to be false
        expect(r.holds?(r.to(9), 9)).to be true
        expect(r.holds?(r.all, -99)).to be true
        expect(r.holds?(r.empty, 15)).to be false
      end
    end

    describe 'between' do
      it 'reads a descending pair as empty' do
        expect(r.empty?(r.between(5, 3))).to be true
        expect(r.between(5, 3)).to eql r.empty
      end
    end

    describe 'intersect' do
      it 'is the shared span' do
        expect(r.shared(r.between(2, 11), r.between(7, 16))).to eql r.between(7, 11)
      end

      # A miss is empty rather than Nothing, which is why nothing here
      # returns a Maybe.
      it 'is empty when they miss' do
        expect(r.shared(r.between(0, 3), r.between(10, 20))).to eql r.empty
      end

      it 'narrows an endless range' do
        expect(r.shared(r.from(10), r.to(20))).to eql r.between(10, 20)
        expect(r.shared(r.all, r.from(5))).to eql r.from(5)
      end
    end

    describe 'overlaps?' do
      it 'is intersect with the answer thrown away' do
        expect(r.overlaps?(r.between(0, 10), r.between(5, 20))).to be true
        expect(r.overlaps?(r.between(0, 3), r.between(10, 20))).to be false
        expect(r.overlaps?(r.all, r.empty)).to be false
      end
    end

    describe 'clamp' do
      it 'pulls to the nearest bound' do
        expect(r.pulled(teens, 5)).to be_just 13
        expect(r.pulled(teens, 30)).to be_just 19
        expect(r.pulled(teens, 15)).to be_just 15
      end

      it 'has no answer for an empty range' do
        expect(r.pulled(r.empty, 15)).to be_nothing
      end

      it 'leaves an open side alone' do
        expect(r.pulled(r.from(13), 99)).to be_just 99
      end
    end

    describe 'lower and upper' do
      it 'are Nothing on the side that is open' do
        expect(r.lowest(teens)).to be_just 13
        expect(r.highest(teens)).to be_just 19
        expect(r.lowest(r.to(9))).to be_nothing
        expect(r.highest(r.from(9))).to be_nothing
        expect(r.lowest(r.all)).to be_nothing
        expect(r.lowest(r.empty)).to be_nothing
      end
    end

    describe 'bounded?' do
      it 'is about having both ends, not about being inhabited' do
        expect(r.bounded?(teens)).to be true
        expect(r.bounded?(r.empty)).to be true
        expect(r.bounded?(r.from(3))).to be false
        expect(r.bounded?(r.all)).to be false
      end
    end
  end
end

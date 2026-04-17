require 'spec_helper'

require 'jade'
require 'jade/module_loader'

module Jade
  describe 'Chainable (<-)' do
    include_context 'with test compiler'

    context 'with Maybe' do
      let(:source) do
        <<~JADE
          module ChainTest exposing (chain, chain_nothing)

          def chain(a: Maybe(Int), b: Maybe(Int)) -> Maybe(Int)
            x <- a
            y <- b
            Just(x + y)
          end

          def chain_nothing(a: Maybe(Int)) -> Maybe(Int)
            x <- a
            y <- Nothing()
            Just(x + y)
          end
        JADE
      end

      before { test_compiler.require('chain_test', source) }

      it 'chains two Just values' do
        result = ChainTest.chain.call(Maybe::Just[3], Maybe::Just[4])
        expect(result).to eql Maybe::Just[7]
      end

      it 'short-circuits on the first Nothing' do
        result = ChainTest.chain.call(Maybe::Nothing[], Maybe::Just[4])
        expect(result).to eql Maybe::Nothing[]
      end

      it 'short-circuits on the second Nothing' do
        result = ChainTest.chain.call(Maybe::Just[3], Maybe::Nothing[])
        expect(result).to eql Maybe::Nothing[]
      end

      it 'short-circuits in chain_nothing' do
        result = ChainTest.chain_nothing.call(Maybe::Just[3])
        expect(result).to eql Maybe::Nothing[]
      end
    end

    context 'with Result' do
      let(:source) do
        <<~JADE
          module ChainTest exposing (chain, chain_err)

          def validate(n: Int) -> Result(Int, String)
            case n
            of 0 then Err("cannot be zero")
            of _ then Ok(n)
            end
          end

          def chain(a: Int, b: Int) -> Result(Int, String)
            x <- validate(a)
            y <- validate(b)
            Ok(x + y)
          end

          def chain_err(a: Int, b: Int) -> Result(Int, String)
            x <- validate(a)
            y <- Err("forced")
            Ok(x + y)
          end
        JADE
      end

      before { test_compiler.require('chain_test', source) }

      it 'chains two Ok values' do
        result = ChainTest.chain.call(3, 4)
        expect(result).to eql Result::Ok[7]
      end

      it 'short-circuits on the first Err' do
        result = ChainTest.chain.call(0, 4)
        expect(result).to eql Result::Err['cannot be zero']
      end

      it 'short-circuits on the second Err' do
        result = ChainTest.chain.call(3, 0)
        expect(result).to eql Result::Err['cannot be zero']
      end

      it 'short-circuits on a forced Err' do
        result = ChainTest.chain_err.call(3, 4)
        expect(result).to eql Result::Err['forced']
      end
    end

    context 'implementing Chainable on a zero-arg type' do
      let(:source) do
        <<~JADE
          module ChainTest exposing (chain)

          type Box = Box(Int)

          implements Chainable(Box) with
            and_then: and_then_box
          end

          def and_then_box(m: Box, f: Box -> Box) -> Box
            f(m)
          end

          def chain(a: Box) -> Box
            x <- a
            Box(1)
          end
        JADE
      end

      it 'raises a compilation error' do
        expect { test_compiler.require('chain_test', source) }
          .to raise_error(RuntimeError, /needs at least one type parameter/)
      end
    end

    context 'generic map via Mappable' do
      let(:source) do
        <<~JADE
          module ChainTest exposing (add_one_maybe, add_one_result)

          def add_one_maybe(m: Maybe(Int)) -> Maybe(Int)
            map(m, (x) -> { x + 1 })
          end

          def add_one_result(r: Result(Int, String)) -> Result(Int, String)
            map(r, (x) -> { x + 1 })
          end
        JADE
      end

      before { test_compiler.require('chain_test', source) }

      it 'maps over Maybe' do
        expect(ChainTest.add_one_maybe.call(Maybe::Just[5])).to eql Maybe::Just[6]
        expect(ChainTest.add_one_maybe.call(Maybe::Nothing[])).to eql Maybe::Nothing[]
      end

      it 'maps over Result' do
        expect(ChainTest.add_one_result.call(Result::Ok[5])).to eql Result::Ok[6]
        expect(ChainTest.add_one_result.call(Result::Err['oops'])).to eql Result::Err['oops']
      end
    end
  end
end

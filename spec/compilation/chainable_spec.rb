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


          def chain_nothing(a: Maybe(Int)) -> Maybe(Int)
            x <- a
            y <- Nothing

            Just(x + y)
        JADE
      end

      before { test_compiler.require('chain_test', source) }

      it 'chains two Just values' do
        expect(ChainTest.chain(3, 4)).to eql 7
      end

      it 'short-circuits on the first Nothing' do
        expect(ChainTest.chain(nil, 4)).to be_nil
      end

      it 'short-circuits on the second Nothing' do
        expect(ChainTest.chain(3, nil)).to be_nil
      end

      it 'short-circuits in chain_nothing' do
        expect(ChainTest.chain_nothing(3)).to be_nil
      end
    end

    context 'with Result' do
      let(:source) do
        <<~JADE
          module ChainTest exposing (chain, chain_err)

          def validate(n: Int) -> Result(Int, String)
            case n
            of 0 -> Err("cannot be zero")
            of _ -> Ok(n)


          def chain(a: Int, b: Int) -> Result(Int, String)
            x <- validate(a)
            y <- validate(b)

            Ok(x + y)


          def chain_err(a: Int, b: Int) -> Result(Int, String)
            x <- validate(a)
            y <- Err("forced")

            Ok(x + y)
        JADE
      end

      before { test_compiler.require('chain_test', source) }

      it 'chains two Ok values' do
        result = ChainTest::Internal.chain(3, 4)
        expect(result).to be_ok(7)
      end

      it 'short-circuits on the first Err' do
        result = ChainTest::Internal.chain(0, 4)
        expect(result).to be_err('cannot be zero')
      end

      it 'short-circuits on the second Err' do
        result = ChainTest::Internal.chain(3, 0)
        expect(result).to be_err('cannot be zero')
      end

      it 'short-circuits on a forced Err' do
        result = ChainTest::Internal.chain_err(3, 4)
        expect(result).to be_err('forced')
      end
    end

    context 'implementing Chainable on a zero-arg type' do
      let(:source) do
        <<~JADE
          module ChainTest exposing (chain)

          type Box = Box(Int)


          implements Chainable(Box) with
            and_then: and_then_box


          def and_then_box(m: Box, f: Box -> Box) -> Box
            f(m)


          def chain(a: Box) -> Box
            x <- a

            Box(1)
        JADE
      end

      it 'raises a compilation error' do
        expect { test_compiler.require('chain_test', source) }
          .to raise_error(CompilationError, /needs at least one type parameter/)
      end
    end

    context 'generic map via Mappable' do
      let(:source) do
        <<~JADE
          module ChainTest exposing (add_one_maybe, add_one_result)

          def add_one_maybe(m: Maybe(Int)) -> Maybe(Int)
            map(m, (x) -> { x + 1 })


          def add_one_result(r: Result(Int, String)) -> Result(Int, String)
            map(r, (x) -> { x + 1 })
        JADE
      end

      before { test_compiler.require('chain_test', source) }

      it 'maps over Maybe' do
        expect(ChainTest.add_one_maybe(5)).to eql 6
        expect(ChainTest.add_one_maybe(nil)).to be_nil
      end

      it 'maps over Result' do
        expect(ChainTest::Internal.add_one_result(Result::Ok[5])).to be_ok(6)
        expect(ChainTest::Internal.add_one_result(Result::Err['oops'])).to be_err('oops')
      end
    end
  end
end

require 'spec_helper'

require 'jade'
require 'jade/module_loader'

module Jade
  describe 'Postfix if' do
    include_context 'with test compiler'

    let(:source) do
      <<~JADE
        module M exposing (abs, classify, double_if_big, mixed_with_block, sign)

        def abs(n: Int) -> Int
          if n < 0 then 0 - n else n


        def sign(n: Int) -> Int
          if n < 0 then 0 - 1
          else if n > 0 then 1
          else 0


        def classify(n: Int) -> String
          if n == 0 then "zero"
          else if n < 0 then "negative"
          else "positive"


        def double_if_big(n: Int, big: Bool) -> Int
          if big then n * 2 else n


        def mixed_with_block(n: Int) -> Int
          if n == 0 then 42
          else if n > 10 then n * 2
          else n
      JADE
    end

    before { test_compiler.require('m', source) }

    it 'evaluates simple postfix conditions' do
      expect(M.abs(-5)).to eql 5
      expect(M.abs(5)).to eql 5
      expect(M.double_if_big(5, true)).to eql 10
      expect(M.double_if_big(5, false)).to eql 5
    end

    it 'cascades right-associatively' do
      expect(M.sign(-3)).to eql(-1)
      expect(M.sign(0)).to eql 0
      expect(M.sign(7)).to eql 1
      expect(M.classify(0)).to eql 'zero'
      expect(M.classify(-2)).to eql 'negative'
      expect(M.classify(2)).to eql 'positive'
    end

    it 'composes inside block-form if/then/else' do
      expect(M.mixed_with_block(0)).to eql 42
      expect(M.mixed_with_block(7)).to eql 7
      expect(M.mixed_with_block(20)).to eql 40
    end
  end

  describe 'Postfix if compositional cases' do
    include_context 'with test compiler'

    let(:source) do
      <<~JADE
        module N exposing (
          block_if_with_postfix_tail,
          in_call_arg,
          in_let,
          in_list,
          in_record,
          multiline,
          postfix_with_block_else,
        )

        def in_call_arg(b: Bool) -> Int
          List.length(if b then [1, 2, 3] else [])


        def in_list(b: Bool) -> List(Int)
          [1, if b then 2 else 99, 3]


        def in_record(b: Bool) -> { x: Int, y: Int }
          {
            x: 1,
            y: if b then 2 else 99,
          }


        def multiline(n: Int) -> Int
          if n > 0 then n * 2 else 0 - n


        def block_if_with_postfix_tail(n: Int) -> Int
          if n > 0 then if n == 0 then 100 else 200 else 0 - 1


        def postfix_with_block_else(n: Int) -> Int
          if n > 0 then 1
          else if n == 0 then 0
          else 0 - 1


        def in_let(b: Bool) -> Int
          x = if b then 1 else 2
          y = if b then 10 else 20

          x + y
      JADE
    end

    before { test_compiler.require('n', source) }

    it 'works inside function call args, lists, records' do
      expect(N.in_call_arg(true)).to eql 3
      expect(N.in_call_arg(false)).to eql 0
      expect(N.in_list(true)).to eql [1, 2, 3]
      expect(N.in_list(false)).to eql [1, 99, 3]
      expect(N::Internal.in_record.call(true).y).to eql 2
      expect(N::Internal.in_record.call(false).y).to eql 99
    end

    it 'spans multiple lines' do
      expect(N.multiline(5)).to eql 10
      expect(N.multiline(-3)).to eql 3
    end

    it 'attaches a postfix tail to a block-if as the leading expression' do
      expect(N.block_if_with_postfix_tail(0)).to eql(-1)
      expect(N.block_if_with_postfix_tail(5)).to eql 200
      expect(N.block_if_with_postfix_tail(-3)).to eql(-1)
    end

    it 'allows a block-if as the else branch of postfix' do
      expect(N.postfix_with_block_else(5)).to eql 1
      expect(N.postfix_with_block_else(0)).to eql 0
      expect(N.postfix_with_block_else(-3)).to eql(-1)
    end

    it 'works on the right-hand side of let bindings' do
      expect(N.in_let(true)).to eql 11
      expect(N.in_let(false)).to eql 22
    end
  end
end

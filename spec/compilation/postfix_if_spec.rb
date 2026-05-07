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
          if n < 0 then
            0 - n
          else
            n
          end
        end

        def sign(n: Int) -> Int
          if n < 0 then
            0 - 1
          else
            if n > 0 then
              1
            else
              0
            end
          end
        end

        def classify(n: Int) -> String
          if n == 0 then
            "zero"
          else
            if n < 0 then
              "negative"
            else
              "positive"
            end
          end
        end

        def double_if_big(n: Int, big: Bool) -> Int
          if big then
            n * 2
          else
            n
          end
        end

        def mixed_with_block(n: Int) -> Int
          if n == 0 then
            42
          else
            if n > 10 then
              n * 2
            else
              n
            end
          end
        end
      JADE
    end

    before { test_compiler.require('m', source) }

    it 'evaluates simple postfix conditions' do
      expect(M.abs.call(-5)).to eql 5
      expect(M.abs.call(5)).to eql 5
      expect(M.double_if_big.call(5, true)).to eql 10
      expect(M.double_if_big.call(5, false)).to eql 5
    end

    it 'cascades right-associatively' do
      expect(M.sign.call(-3)).to eql(-1)
      expect(M.sign.call(0)).to eql 0
      expect(M.sign.call(7)).to eql 1
      expect(M.classify.call(0)).to eql 'zero'
      expect(M.classify.call(-2)).to eql 'negative'
      expect(M.classify.call(2)).to eql 'positive'
    end

    it 'composes inside block-form if/then/else' do
      expect(M.mixed_with_block.call(0)).to eql 42
      expect(M.mixed_with_block.call(7)).to eql 7
      expect(M.mixed_with_block.call(20)).to eql 40
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
          List.length(if b then
            [1, 2, 3]
          else
            []
          end)
        end

        def in_list(b: Bool) -> List(Int)
          [1, if b then
            2
          else
            99
          end, 3]
        end

        def in_record(b: Bool) -> { x: Int, y: Int }
          {
            x: 1,
            y: if b then
              2
            else
              99
            end,
          }
        end

        def multiline(n: Int) -> Int
          if n > 0 then
            n * 2
          else
            0 - n
          end
        end

        def block_if_with_postfix_tail(n: Int) -> Int
          if n > 0 then
            if n == 0 then
              100
            else
              200
            end
          else
            0 - 1
          end
        end

        def postfix_with_block_else(n: Int) -> Int
          if n > 0 then
            1
          else
            if n == 0 then
              0
            else
              0 - 1
            end
          end
        end

        def in_let(b: Bool) -> Int
          x = if b then
            1
          else
            2
          end
          y = if b then
            10
          else
            20
          end

          x + y
        end
      JADE
    end

    before { test_compiler.require('n', source) }

    it 'works inside function call args, lists, records' do
      expect(N.in_call_arg.call(true)).to eql 3
      expect(N.in_call_arg.call(false)).to eql 0
      expect(N.in_list.call(true)).to eql [1, 2, 3]
      expect(N.in_list.call(false)).to eql [1, 99, 3]
      expect(N.in_record.call(true).y).to eql 2
      expect(N.in_record.call(false).y).to eql 99
    end

    it 'spans multiple lines' do
      expect(N.multiline.call(5)).to eql 10
      expect(N.multiline.call(-3)).to eql 3
    end

    it 'attaches a postfix tail to a block-if as the leading expression' do
      expect(N.block_if_with_postfix_tail.call(0)).to eql(-1)
      expect(N.block_if_with_postfix_tail.call(5)).to eql 200
      expect(N.block_if_with_postfix_tail.call(-3)).to eql(-1)
    end

    it 'allows a block-if as the else branch of postfix' do
      expect(N.postfix_with_block_else.call(5)).to eql 1
      expect(N.postfix_with_block_else.call(0)).to eql 0
      expect(N.postfix_with_block_else.call(-3)).to eql(-1)
    end

    it 'works on the right-hand side of let bindings' do
      expect(N.in_let.call(true)).to eql 11
      expect(N.in_let.call(false)).to eql 22
    end
  end
end

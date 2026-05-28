require 'spec_helper'

require 'jade'
require 'jade/module_loader'

module Jade
  describe 'Ternary `?:`' do
    include_context 'with test compiler'

    let(:source) do
      <<~JADE
        module M exposing (abs, classify, double_if_big, mixed_with_block, sign)

        def abs(n: Int) -> Int
          n < 0 ? 0 - n : n
        end


        def sign(n: Int) -> Int
          n < 0 ? 0 - 1 : n > 0 ? 1 : 0
        end


        def classify(n: Int) -> String
          n == 0 ? "zero" : n < 0 ? "negative" : "positive"
        end


        def double_if_big(n: Int, big: Bool) -> Int
          big ? n * 2 : n
        end


        def mixed_with_block(n: Int) -> Int
          n == 0 ? 42 : n > 10 ? n * 2 : n
        end
      JADE
    end

    before { test_compiler.require('m', source) }

    it 'evaluates simple ternary expressions' do
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

  describe 'Ternary compositional cases' do
    include_context 'with test compiler'

    let(:source) do
      <<~JADE
        module N exposing (
          in_call_arg,
          in_let,
          in_list,
          in_record,
          multiline,
          nested_in_else,
          nested_in_then,
        )

        def in_call_arg(b: Bool) -> Int
          List.length(b ? [1, 2, 3] : [])
        end


        def in_list(b: Bool) -> List(Int)
          [1, b ? 2 : 99, 3]
        end


        def in_record(b: Bool) -> { x: Int, y: Int }
          {
            x: 1,
            y: b ? 2 : 99,
          }
        end


        def multiline(n: Int) -> Int
          n > 0 ? n * 2 : 0 - n
        end


        def nested_in_then(n: Int) -> Int
          n > 0 ? n == 0 ? 100 : 200 : 0 - 1
        end


        def nested_in_else(n: Int) -> Int
          n > 0 ? 1 : n == 0 ? 0 : 0 - 1
        end


        def in_let(b: Bool) -> Int
          x = b ? 1 : 2
          y = b ? 10 : 20
          x + y
        end
      JADE
    end

    before { test_compiler.require('n', source) }

    it 'works inside function call args, lists, records' do
      expect(N.in_call_arg(true)).to eql 3
      expect(N.in_call_arg(false)).to eql 0
      expect(N.in_list(true)).to eql [1, 2, 3]
      expect(N.in_list(false)).to eql [1, 99, 3]
      expect(N::Internal.in_record(true).y).to eql 2
      expect(N::Internal.in_record(false).y).to eql 99
    end

    it 'spans multiple lines' do
      expect(N.multiline(5)).to eql 10
      expect(N.multiline(-3)).to eql 3
    end

    it 'nests a ternary in the then-arm' do
      expect(N.nested_in_then(0)).to eql(-1)
      expect(N.nested_in_then(5)).to eql 200
      expect(N.nested_in_then(-3)).to eql(-1)
    end

    it 'nests a ternary in the else-arm (right-associative)' do
      expect(N.nested_in_else(5)).to eql 1
      expect(N.nested_in_else(0)).to eql 0
      expect(N.nested_in_else(-3)).to eql(-1)
    end

    it 'works on the right-hand side of let bindings' do
      expect(N.in_let(true)).to eql 11
      expect(N.in_let(false)).to eql 22
    end
  end
end

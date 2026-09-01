require 'spec_helper'

require 'jade'
require 'jade/module_loader'

module Jade
  # Precedence is applied by a pass over the AST, so it reaches an expression
  # only if the pass walks to it.
  describe 'Operator precedence' do
    include_context 'with test compiler'

    before do
      test_compiler.require(source)
    end

    let(:source) do
      <<~JADE
        module Fix exposing (banded?, in_branch, in_else, plain, under_if)

        type Span
          = Bounded(Int, Int)
          | Anything


        def plain(low: Int, value: Int, high: Int) -> Bool
          (low <= value) && (value <= high)
        end


        def banded?(span: Span, value: Int) -> Bool
          case span
          in Bounded(low, high) then low <= value && value <= high
          in Anything then True
          end
        end


        def in_branch(n: Int) -> Int
          case n
          in 0 then 0
          else 1 + 2 * 3
          end
        end


        def in_else(n: Int) -> Int
          case n
          in 0 then 1 + 2 * 3
          else 0
          end
        end


        def under_if(n: Int) -> Int
          n == 0 ? 0 : 1 + 2 * 3
        end
      JADE
    end

    it 'holds in a function body' do
      expect(Fix::Internal.plain(1, 3, 5)).to be true
      expect(Fix::Internal.plain(1, 9, 5)).to be false
    end

    it 'holds inside a case branch' do
      expect(Fix::Internal.banded?(Fix::Bounded[1, 5], 3)).to be true
      expect(Fix::Internal.banded?(Fix::Bounded[1, 5], 9)).to be false
    end

    it 'holds in every arm of a case' do
      expect(Fix::Internal.in_branch(1)).to eql 7
      expect(Fix::Internal.in_else(0)).to eql 7
    end

    it 'holds under a ternary' do
      expect(Fix::Internal.under_if(1)).to eql 7
    end
  end
end

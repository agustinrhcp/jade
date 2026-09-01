require 'spec_helper'

require 'jade'
require 'jade/module_loader'

module Jade
  # A predicate carrying an interface constraint compiles to a dictionary
  # -passing method whose name embeds the Jade one, and `?` is legal in a Ruby
  # method name only at the end.
  describe 'A predicate with a constraint' do
    include_context 'with test compiler'

    before do
      test_compiler.require(source)
    end

    let(:source) do
      <<~JADE
        module Preds exposing (chars_rising?, ints_rising?, starts_rising?)

        def rising?(a: a, b: a) -> Bool
          a < b
        end


        def head_rising?(xs: List(a)) -> Bool
          case xs
          in [] then False
          in [_] then False
          in [x, y | _] then rising?(x, y)
          end
        end


        def ints_rising?(a: Int, b: Int) -> Bool
          rising?(a, b)
        end


        def chars_rising?(a: Char, b: Char) -> Bool
          rising?(a, b)
        end


        def starts_rising?(xs: List(Int)) -> Bool
          head_rising?(xs)
        end
      JADE
    end

    it 'compiles to a name Ruby will accept' do
      expect(Preds::Internal.ints_rising?(1, 2)).to be true
      expect(Preds::Internal.ints_rising?(2, 1)).to be false
    end

    it 'carries the dictionary through' do
      expect(Preds::Internal.chars_rising?('a', 'b')).to be true
      expect(Preds::Internal.chars_rising?('b', 'a')).to be false
    end

    it 'is callable from another constrained function' do
      expect(Preds::Internal.starts_rising?([1, 2, 3])).to be true
      expect(Preds::Internal.starts_rising?([3, 2, 1])).to be false
      expect(Preds::Internal.starts_rising?([])).to be false
    end
  end
end

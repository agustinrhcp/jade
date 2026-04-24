require 'spec_helper'

require 'jade'

module Jade
  describe 'String' do
    include_context 'with test compiler'

    let(:pepe_source) do
      <<~JADE
        module Pepe exposing(str_to_int)

        def str_to_int(str: String) -> Maybe(Int)
          String.to_int(str)
        end
      JADE
    end

    before do
      test_compiler.require('pepe', pepe_source)
    end

    it 'works' do
      expect(Pepe.str_to_int.call('1')).to eql Maybe::Just[1]
      expect(Pepe.str_to_int.call('pepe')).to eql Maybe::Nothing[]
    end
  end

  describe 'uncons / cons / from_char / map' do
    include_context 'with test compiler'

    let(:source) do
      <<~JADE
        module Strs exposing(first_char, prepend, single, walk)

        def first_char(s: String) -> Maybe(Char)
          case String.uncons(s)
          of Just((c, _)) then Just(c)
          of Nothing then Nothing()
          end
        end

        def prepend(c: Char, s: String) -> String
          String.cons(c, s)
        end

        def single(c: Char) -> String
          String.from_char(c)
        end

        def walk(s: String) -> List(Char)
          case String.uncons(s)
          of Just((c, rest)) then [c] ++ walk(rest)
          of Nothing then []
          end
        end
      JADE
    end

    before { test_compiler.require('strs', source) }

    it 'uncons returns head char' do
      expect(Strs.first_char.call('abc')).to eql Maybe::Just['a']
      expect(Strs.first_char.call('')).to eql Maybe::Nothing[]
    end

    it 'cons prepends a char' do
      expect(Strs.prepend.call('x', 'yz')).to eql 'xyz'
    end

    it 'from_char wraps a char as a string' do
      expect(Strs.single.call('q')).to eql 'q'
    end

    it 'walks a string via repeated uncons' do
      expect(Strs.walk.call('abc')).to eql ['a', 'b', 'c']
      expect(Strs.walk.call('')).to eql []
    end
  end

  describe 'map' do
    include_context 'with test compiler'

    let(:source) do
      <<~JADE
        module StrMap exposing(double)

        def double(s: String) -> String
          String.map(s, (c) -> { c })
        end
      JADE
    end

    before { test_compiler.require('str_map', source) }

    it 'maps over each char' do
      expect(StrMap.double.call('abc')).to eql 'abc'
    end
  end

  describe '++ operator' do
    include_context 'with test compiler'

    context 'on strings' do
      let(:source) do
        <<~JADE
          module Concat exposing (greet, join)

          def greet(name: String) -> String
            "Hello, " ++ name ++ "!"
          end

          def join(a: String, b: String, sep: String) -> String
            a ++ sep ++ b
          end
        JADE
      end

      before { test_compiler.require('concat', source) }

      it 'concatenates strings' do
        expect(Concat.greet.call('Alice')).to eql 'Hello, Alice!'
        expect(Concat.join.call('foo', 'bar', '-')).to eql 'foo-bar'
      end
    end

    context 'on lists' do
      let(:source) do
        <<~JADE
          module Concat exposing (combine)

          def combine(a: List(Int), b: List(Int)) -> List(Int)
            a ++ b
          end
        JADE
      end

      before { test_compiler.require('concat', source) }

      it 'concatenates lists' do
        expect(Concat.combine.call([1, 2], [3, 4])).to eql [1, 2, 3, 4]
        expect(Concat.combine.call([], [1])).to eql [1]
      end
    end
  end
end

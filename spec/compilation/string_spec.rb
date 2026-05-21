require 'spec_helper'

require 'jade'

module Jade
  describe 'String' do
    include_context 'with test compiler'

    let(:pepe_source) do
      <<~JADE
        module Pepe exposing (str_to_int)

        def str_to_int(str: String) -> Maybe(Int)
          String.to_int(str)
      JADE
    end

    before do
      test_compiler.require('pepe', pepe_source)
    end

    it 'works' do
      expect(Pepe.str_to_int('1')).to eql 1
      expect(Pepe.str_to_int('pepe')).to be_nil
    end
  end

  describe 'uncons / cons / from_char / map' do
    include_context 'with test compiler'

    let(:source) do
      <<~JADE
        module Strs exposing (first_char, prepend, single, walk)

        def first_char(s: String) -> Maybe(Char)
          case String.uncons(s)
          of Just((c, _)) -> Just(c)
          of Nothing -> Nothing


        def prepend(c: Char, s: String) -> String
          String.cons(c, s)


        def single(c: Char) -> String
          String.from_char(c)


        def walk(s: String) -> List(Char)
          case String.uncons(s)
          of Just((c, rest)) -> [c] ++ walk(rest)
          of Nothing -> []
      JADE
    end

    before { test_compiler.require('strs', source) }

    it 'uncons returns head char' do
      expect(Strs::Internal.first_char.call('abc')).to be_just('a')
      expect(Strs::Internal.first_char.call('')).to be_nothing
    end

    it 'cons prepends a char' do
      expect(Strs::Internal.prepend.call('x', 'yz')).to eql 'xyz'
    end

    it 'from_char wraps a char as a string' do
      expect(Strs::Internal.single.call('q')).to eql 'q'
    end

    it 'walks a string via repeated uncons' do
      expect(Strs::Internal.walk.call('abc')).to eql ['a', 'b', 'c']
      expect(Strs::Internal.walk.call('')).to eql []
    end
  end

  describe 'map' do
    include_context 'with test compiler'

    let(:source) do
      <<~JADE
        module StrMap exposing (double)

        def double(s: String) -> String
          String.map(s, (c) -> { c })
      JADE
    end

    before { test_compiler.require('str_map', source) }

    it 'maps over each char' do
      expect(StrMap.double('abc')).to eql 'abc'
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


          def join(a: String, b: String, sep: String) -> String
            a ++ sep ++ b
        JADE
      end

      before { test_compiler.require('concat', source) }

      it 'concatenates strings' do
        expect(Concat.greet('Alice')).to eql 'Hello, Alice!'
        expect(Concat.join('foo', 'bar', '-')).to eql 'foo-bar'
      end
    end

    context 'on lists' do
      let(:source) do
        <<~JADE
          module Concat exposing (combine)

          def combine(a: List(Int), b: List(Int)) -> List(Int)
            a ++ b
        JADE
      end

      before { test_compiler.require('concat', source) }

      it 'concatenates lists' do
        expect(Concat.combine([1, 2], [3, 4])).to eql [1, 2, 3, 4]
        expect(Concat.combine([], [1])).to eql [1]
      end
    end
  end

  describe 'string escape sequences' do
    include_context 'with test compiler'

    let(:source) do
      <<~'JADE'
        module Escape exposing (backslash, newline, quote, tab)

        def newline -> String
          "Hello\nWorld"


        def tab -> String
          "col1\tcol2"


        def backslash -> String
          "back\\slash"


        def quote -> String
          "say \"hi\""
      JADE
    end

    before { test_compiler.require('escape', source) }

    it 'resolves \\n to a newline character' do
      expect(Escape.newline).to eql "Hello\nWorld"
    end

    it 'resolves \\t to a tab character' do
      expect(Escape.tab).to eql "col1\tcol2"
    end

    it 'resolves \\\\ to a backslash' do
      expect(Escape.backslash).to eql 'back\slash'
    end

    it 'resolves \\" to a double quote' do
      expect(Escape.quote).to eql 'say "hi"'
    end
  end
end

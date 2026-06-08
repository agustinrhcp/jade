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
        end
      JADE
    end

    before do
      test_compiler.require('pepe', pepe_source)
    end

    it 'works' do
      expect(Pepe.str_to_int('1')).to eql 1
      expect(Pepe.str_to_int('pepe')).to be_nil
    end

    it 'parses zero-padded decimal strings (not octal)' do
      expect(Pepe.str_to_int('09')).to eql 9
      expect(Pepe.str_to_int('08')).to eql 8
      expect(Pepe.str_to_int('007')).to eql 7
      expect(Pepe.str_to_int('0')).to eql 0
      expect(Pepe.str_to_int('-05')).to eql(-5)
    end

    it 'rejects non-decimal numeric forms' do
      expect(Pepe.str_to_int('0x10')).to be_nil
      expect(Pepe.str_to_int('1.5')).to be_nil
      expect(Pepe.str_to_int('')).to be_nil
    end
  end

  describe 'indexes / slice' do
    include_context 'with test compiler'

    let(:source) do
      <<~JADE
        module Slicer exposing (head, pipes, tail_after)

        def pipes(s: String) -> List(Int)
          String.indexes(s, "|")
        end


        def head(s: String, to: Int) -> String
          String.slice(s, 0, to)
        end


        def tail_after(s: String, from: Int) -> String
          String.slice(s, from, String.length(s))
        end
      JADE
    end

    before do
      test_compiler.require('slicer', source)
    end

    it 'indexes reports every pipe position' do
      expect(Slicer.pipes('a|b|c|d|e')).to eql [1, 3, 5, 7]
      expect(Slicer.pipes('nope')).to eql []
    end

    it 'slice extracts the leading field' do
      expect(Slicer.head('abc|def', 3)).to eql 'abc'
    end

    it 'slice to length keeps a pipe-bearing subject intact (the parse case)' do
      raw = 'deadbeef|2024-09-02T09:00:00Z|Ada|Refactor | rename module'
      third = Slicer.pipes(raw)[2]
      expect(Slicer.tail_after(raw, third + 1)).to eql 'Refactor | rename module'
    end

    it 'slice clamps out-of-range and negative bounds' do
      expect(Slicer.head('abcdef', 100)).to eql 'abcdef'
      expect(Slicer.tail_after('abcdef', -2)).to eql 'ef'
    end
  end

  describe 'uncons / cons / from_char / map' do
    include_context 'with test compiler'

    let(:source) do
      <<~JADE
        module Strs exposing (first_char, prepend, single, walk)

        def first_char(s: String) -> Maybe(Char)
          case String.uncons(s)
          in Just((c, _)) then Just(c)
          in Nothing then Nothing
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
          in Just((c, rest)) then [c] ++ walk(rest)
          in Nothing then []
          end
        end
      JADE
    end

    before { test_compiler.require('strs', source) }

    it 'uncons returns head char' do
      expect(Strs::Internal.first_char('abc')).to be_just('a')
      expect(Strs::Internal.first_char('')).to be_nothing
    end

    it 'cons prepends a char' do
      expect(Strs::Internal.prepend('x', 'yz')).to eql 'xyz'
    end

    it 'from_char wraps a char as a string' do
      expect(Strs::Internal.single('q')).to eql 'q'
    end

    it 'walks a string via repeated uncons' do
      expect(Strs::Internal.walk('abc')).to eql ['a', 'b', 'c']
      expect(Strs::Internal.walk('')).to eql []
    end
  end

  describe 'map' do
    include_context 'with test compiler'

    let(:source) do
      <<~JADE
        module StrMap exposing (double)

        def double(s: String) -> String
          String.map(s, (c) -> { c })
        end
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
          end


          def join(a: String, b: String, sep: String) -> String
            a ++ sep ++ b
          end
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
          end
        JADE
      end

      before { test_compiler.require('concat', source) }

      it 'concatenates lists' do
        expect(Concat.combine([1, 2], [3, 4])).to eql [1, 2, 3, 4]
        expect(Concat.combine([], [1])).to eql [1]
      end
    end

    context 'mixed with other operators' do
      let(:source) do
        <<~JADE
          module Mixed exposing (mid, piped)

          def piped(a: List(Int), b: List(Int)) -> List(Int)
            a ++ b |> List.reverse
          end


          def mid(a: String, b: String, c: String) -> Bool
            (a ++ b == c)
          end
        JADE
      end

      before { test_compiler.require('mixed', source) }

      it 'binds ++ tighter than |> and looser than ==' do
        expect(Mixed.piped([1, 2], [3, 4])).to eql [4, 3, 2, 1]
        expect(Mixed.mid('foo', 'bar', 'foobar')).to be true
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
        end


        def tab -> String
          "col1\tcol2"
        end


        def backslash -> String
          "back\\slash"
        end


        def quote -> String
          "say \"hi\""
        end
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

  describe 'phase-1 additions' do
    include_context 'with test compiler'

    let(:source) do
      <<~JADE
        module S exposing (
          char_count,
          ends?,
          has?,
          ltrim,
          lwr,
          mlines,
          rep,
          round_trip,
          rtrim,
          starts?,
          trim_,
          upr,
          ws,
        )

        def trim_(s: String) -> String
          String.trim(s)
        end


        def ltrim(s: String) -> String
          String.trim_left(s)
        end


        def rtrim(s: String) -> String
          String.trim_right(s)
        end


        def lwr(s: String) -> String
          String.to_lower(s)
        end


        def upr(s: String) -> String
          String.to_upper(s)
        end


        def has?(s: String, sub: String) -> Bool
          String.contains?(s, sub)
        end


        def starts?(s: String, p: String) -> Bool
          String.starts_with?(s, p)
        end


        def ends?(s: String, p: String) -> Bool
          String.ends_with?(s, p)
        end


        def rep(s: String, t: String, r: String) -> String
          String.replace(s, t, r)
        end


        def ws(s: String) -> List(String)
          String.words(s)
        end


        def mlines(s: String) -> List(String)
          String.lines(s)
        end


        def char_count(s: String) -> Int
          s
            |> String.to_list
            |> List.length
        end


        def round_trip(s: String) -> String
          s
            |> String.to_list
            |> String.from_list
        end
      JADE
    end

    before { test_compiler.require('s', source) }

    it 'trims whitespace' do
      expect(S.trim_('  hi  ')).to eql 'hi'
      expect(S.ltrim('  hi  ')).to eql 'hi  '
      expect(S.rtrim('  hi  ')).to eql '  hi'
    end

    it 'changes case' do
      expect(S.lwr('AbC')).to eql 'abc'
      expect(S.upr('AbC')).to eql 'ABC'
    end

    it 'contains / starts_with / ends_with' do
      expect(S.has?('hello world', 'lo w')).to be true
      expect(S.has?('hello world', 'zz')).to be false
      expect(S.starts?('hello', 'hel')).to be true
      expect(S.starts?('hello', 'lo')).to be false
      expect(S.ends?('hello', 'llo')).to be true
      expect(S.ends?('hello', 'he')).to be false
    end

    it 'replaces literal substrings (no regex)' do
      expect(S.rep('a.b.c', '.', '-')).to eql 'a-b-c'
      expect(S.rep('abc', 'x', 'y')).to eql 'abc'
    end

    it 'splits into words and lines' do
      expect(S.ws("  one  two\tthree ")).to eql ['one', 'two', 'three']
      expect(S.ws('')).to eql []
      expect(S.mlines("a\nb\nc")).to eql ['a', 'b', 'c']
      expect(S.mlines("a\nb\n")).to eql ['a', 'b', '']
    end

    it 'to_list / from_list — char count and string round-trip' do
      expect(S.char_count('abc')).to eql 3
      expect(S.char_count('')).to eql 0
      expect(S.round_trip('hello')).to eql 'hello'
      expect(S.round_trip('')).to eql ''
    end
  end

  describe 'slice' do
    include_context 'with test compiler'

    let(:source) do
      <<~JADE
        module S exposing (slice)

        def slice(s: String, a: Int, b: Int) -> String
          String.slice(s, a, b)
        end
      JADE
    end

    before { test_compiler.require('s', source) }

    it 'returns the half-open substring' do
      expect(S.slice('abcdef', 0, 3)).to eql 'abc'
      expect(S.slice('abcdef', 2, 5)).to eql 'cde'
    end

    it 'empty for zero-length range' do
      expect(S.slice('abc', 1, 1)).to eql ''
    end

    it 'clamps a too-large end' do
      expect(S.slice('abc', 1, 99)).to eql 'bc'
    end

    it 'empty when start is past end of string' do
      expect(S.slice('abc', 5, 9)).to eql ''
    end
  end
end

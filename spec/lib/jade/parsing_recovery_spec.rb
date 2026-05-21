require 'spec_helper'

require 'jade/parsing'
require 'jade/lexer'
require 'jade/ast'
require 'jade/formatter'
require 'jade/frontend/comment_attacher'

module Jade
  describe Parsing, 'tolerant mode' do
    def parse(text)
      source = Source.new(uri: 'test.jd', text: text)
      tokens = Lexer.tokenize(source)
      Parsing.parse(tokens, entry: source.uri, tolerant: true)
    end

    def format_ast(ast, source_text)
      source = Source.new(uri: 'test.jd', text: source_text)
      Formatter.format(ast, comments: [], source:)
    end

    describe 'recovery from broken declarations' do
      it 'skips a broken def and recovers the next one' do
        result = parse(<<~JADE)
          module M exposing (a, c)

          def a -> Int
            1

          def b -> Int
            @@@ broken

          def c -> Int
            3
        JADE

        result => Ok([ast, _, diagnostics])
        expect(diagnostics.items.length).to eq(1)
        expect(ast.body.expressions.map(&:name)).to eq(%w[a c])
      end

      it 'recovers when the first declaration is broken' do
        result = parse(<<~JADE)
          module M exposing (b)

          def a -> @@@

          def b -> Int
            2
        JADE

        result => Ok([ast, _, diagnostics])
        expect(diagnostics.items.length).to be >= 1
        expect(ast.body.expressions.map(&:name)).to include('b')
      end

      it 'recovers when the last declaration is broken' do
        result = parse(<<~JADE)
          module M exposing (a)

          def a -> Int
            1

          def b -> @@@
        JADE

        result => Ok([ast, _, diagnostics])
        expect(diagnostics.items.length).to be >= 1
        expect(ast.body.expressions.map(&:name)).to include('a')
      end

      it 'collects diagnostics from two broken declarations' do
        result = parse(<<~JADE)
          module M exposing (c)

          def a -> @@@

          def b -> @@@

          def c -> Int
            3
        JADE

        result => Ok([ast, _, diagnostics])
        expect(diagnostics.items.length).to be >= 2
        expect(ast.body.expressions.map(&:name)).to include('c')
      end

      it 'handles garbage tokens between declarations' do
        result = parse(<<~JADE)
          module M exposing (a, b)

          def a -> Int
            1

          @@@ stray garbage @@@

          def b -> Int
            2
        JADE

        result => Ok([ast, _, diagnostics])
        expect(diagnostics.items.length).to be >= 1
        expect(ast.body.expressions.map(&:name)).to eq(%w[a b])
      end

      it 'never raises on completely malformed input' do
        expect {
          parse('@@@ all garbage @@@')
        }.not_to raise_error
      end
    end

    describe 'tolerant returns a usable partial AST for the formatter' do
      it 'formats the well-formed regions' do
        result = parse(<<~JADE)
          module M exposing (a, c)

          def a -> Int
            1

          def b -> Int
            @@@ broken

          def c -> Int
            3
        JADE

        result => Ok([ast, _, _])
        formatted = format_ast(ast, '')

        expect(formatted).to include('def a -> Int')
        expect(formatted).to include('def c -> Int')
        expect(formatted).not_to include('@@@')
      end
    end

    describe 'trailing commas (now accepted)' do
      it 'accepts a trailing comma in a function call' do
        result = parse(<<~JADE)
          module M exposing (x)

          def x -> Int
            f(1, 2,)
        JADE

        result => Ok([ast, _, diagnostics])
        expect(diagnostics).to be_empty
        expect(ast.body.expressions.first.name).to eq('x')
      end

      it 'accepts a trailing comma in a list literal' do
        result = parse(<<~JADE)
          module M exposing (xs)

          def xs -> List(Int)
            [1, 2, 3,]
        JADE

        result => Ok([_, _, diagnostics])
        expect(diagnostics).to be_empty
      end

      it 'accepts a trailing comma in a record literal' do
        result = parse(<<~JADE)
          module M exposing (r)

          def r -> { a: Int, b: Int }
            { a: 1, b: 2, }
        JADE

        result => Ok([_, _, diagnostics])
        expect(diagnostics).to be_empty
      end

      it 'accepts a trailing comma in implements method list' do
        result = parse(<<~JADE)
          module M exposing (..)

          interface I(a) with
            f : a -> a,
            g : a -> a,

          implements I(Int) with
            f: f_int,
            g: g_int,
        JADE

        result => Ok([_, _, diagnostics])
        expect(diagnostics).to be_empty
      end

      it 'accepts a trailing comma in interop fn list' do
        result = parse(<<~JADE)
          module M exposing (..)

          uses Ruby::Date with
            today : Int,
            tomorrow : Int,
        JADE

        result => Ok([_, _, diagnostics])
        expect(diagnostics).to be_empty
      end

      it 'accepts a trailing comma in function call type params' do
        result = parse(<<~JADE)
          module M exposing (f)

          def f(x: Maybe(Int,)) -> Int
            0
        JADE

        result => Ok([_, _, diagnostics])
        expect(diagnostics).to be_empty
      end
    end

    describe 'strict mode preserved' do
      it 'still fails strict parse on broken input' do
        source = Source.new(uri: 'test.jd', text: 'def a -> @@@')
        tokens = Lexer.tokenize(source)
        result = Parsing.parse(tokens, entry: source.uri)

        expect(result).to be_a(Err)
      end

      it 'still succeeds strict parse on valid input' do
        source = Source.new(uri: 'test.jd', text: <<~JADE)
          module M exposing (a)

          def a -> Int
            1
        JADE
        tokens = Lexer.tokenize(source)
        result = Parsing.parse(tokens, entry: source.uri)

        expect(result).to be_a(Ok)
      end
    end
  end
end

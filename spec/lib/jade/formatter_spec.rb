require 'spec_helper'

require 'jade/ast'
require 'jade/parsing'
require 'jade/lexer'
require 'jade/formatter'

module Jade
  describe Formatter do
    let(:source) { Source.new(uri: 'test', text:) }

    subject do
      Lexer.tokenize(source)
        .then { Parsing.parse(it) }
        .map { Formatter.format(it) } => Ok(result)

      result
    end

    context 'literals' do
      context 'int' do
        let(:text) { "42" }
        it { is_expected.to eql "42" }
      end

      context 'float' do
        let(:text) { "3.14" }
        it { is_expected.to eql "3.14" }
      end

      context 'bool True' do
        let(:text) { "True" }
        it { is_expected.to eql "True" }
      end

      context 'bool False' do
        let(:text) { "False" }
        it { is_expected.to eql "False" }
      end

      context 'string' do
        let(:text) { '"hello"' }
        it { is_expected.to eql '"hello"' }
      end
    end

    context 'variable binding and reference' do
      let(:text) do
        <<~JADE.strip
          x = 42
          x
        JADE
      end

      it { is_expected.to eql "x = 42\nx" }
    end

    context 'infix application' do
      let(:text) { "a + b" }
      it { is_expected.to eql "a + b" }

      context 'nested' do
        let(:text) { "a + b * c" }
        it { is_expected.to eql "a + b * c" }
      end

      context 'comparison' do
        let(:text) { "x == 0" }
        it { is_expected.to eql "x == 0" }
      end
    end

    context 'grouping' do
      let(:text) { "(a + b)" }
      it { is_expected.to eql "(a + b)" }
    end

    context 'function call' do
      let(:text) { "f(a, b)" }
      it { is_expected.to eql "f(a, b)" }

      context 'no args' do
        let(:text) { "f()" }
        it { is_expected.to eql "f()" }
      end

      context 'nested' do
        let(:text) { "f(g(x), 1)" }
        it { is_expected.to eql "f(g(x), 1)" }
      end
    end

    context 'list' do
      let(:text) { "[1, 2, 3]" }
      it { is_expected.to eql "[1, 2, 3]" }
    end

    context 'tuple' do
      let(:text) { "(1, 2)" }
      it { is_expected.to eql "(1, 2)" }

      context 'three elements' do
        let(:text) { "(1, 2, 3)" }
        it { is_expected.to eql "(1, 2, 3)" }
      end
    end

    context 'record literal' do
      let(:text) { '{ name: "Alice", age: 30 }' }
      it { is_expected.to eql '{ name: "Alice", age: 30 }' }
    end

    context 'record update' do
      let(:text) { '{ person | name: "Bob" }' }
      it { is_expected.to eql '{ person | name: "Bob" }' }
    end

    context 'lambda' do
      let(:text) { '(x) -> { x + 1 }' }
      it { is_expected.to eql '(x) -> { x + 1 }' }

      context 'multiple params' do
        let(:text) { '(x, y) -> { x + y }' }
        it { is_expected.to eql '(x, y) -> { x + y }' }
      end
    end

    context 'if/then/else' do
      let(:text) do
        <<~JADE.strip
          if x == 0 then
            1
          else
            2
          end
        JADE
      end

      it do
        is_expected.to eql <<~JADE.strip
          if x == 0 then
            1
          else
            2
          end
        JADE
      end

      context 'nested inside a function body' do
        let(:text) do
          <<~JADE.strip
            def abs(x: Int) -> Int
              if x < 0 then
                0 - x
              else
                x
              end
            end
          JADE
        end

        it do
          is_expected.to eql <<~JADE.strip
            def abs(x: Int) -> Int
              if x < 0 then
                0 - x
              else
                x
              end
            end
          JADE
        end
      end
    end

    context 'case/of' do
      context 'single-expression branches' do
        let(:text) do
          <<~JADE.strip
            case x
            of True then 1
            of False then 0
            end
          JADE
        end

        it do
          is_expected.to eql <<~JADE.strip
            case x
            of True then 1
            of False then 0
            end
          JADE
        end
      end

      context 'wildcard pattern' do
        let(:text) do
          <<~JADE.strip
            case x
            of _ then 0
            end
          JADE
        end

        it do
          is_expected.to eql <<~JADE.strip
            case x
            of _ then 0
            end
          JADE
        end
      end

      context 'constructor with args' do
        let(:text) do
          <<~JADE.strip
            case m
            of Just(x) then x
            of Nothing then 0
            end
          JADE
        end

        it do
          is_expected.to eql <<~JADE.strip
            case m
            of Just(x) then x
            of Nothing then 0
            end
          JADE
        end
      end

      context 'tuple pattern' do
        let(:text) do
          <<~JADE.strip
            case pair
            of (a, b) then a
            end
          JADE
        end

        it do
          is_expected.to eql <<~JADE.strip
            case pair
            of (a, b) then a
            end
          JADE
        end
      end

      context 'record pattern' do
        let(:text) do
          <<~JADE.strip
            case p
            of { x: a, y: b } then a
            end
          JADE
        end

        it do
          is_expected.to eql <<~JADE.strip
            case p
            of { x: a, y: b } then a
            end
          JADE
        end
      end

      context 'literal pattern' do
        let(:text) do
          <<~JADE.strip
            case n
            of 0 then "zero"
            of _ then "other"
            end
          JADE
        end

        it do
          is_expected.to eql <<~JADE.strip
            case n
            of 0 then "zero"
            of _ then "other"
            end
          JADE
        end
      end
    end

    context 'function declaration' do
      context 'single expression body' do
        let(:text) do
          <<~JADE.strip
            def add(a: Int, b: Int) -> Int
              a + b
            end
          JADE
        end

        it do
          is_expected.to eql <<~JADE.strip
            def add(a: Int, b: Int) -> Int
              a + b
            end
          JADE
        end
      end

      context 'multi-expression body' do
        let(:text) do
          <<~JADE.strip
            def compute(x: Int) -> Int
              y = x + 1
              y * 2
            end
          JADE
        end

        it do
          is_expected.to eql <<~JADE.strip
            def compute(x: Int) -> Int
              y = x + 1
              y * 2
            end
          JADE
        end
      end

      context 'no params' do
        let(:text) do
          <<~JADE.strip
            def zero() -> Int
              0
            end
          JADE
        end

        it do
          is_expected.to eql <<~JADE.strip
            def zero() -> Int
              0
            end
          JADE
        end
      end
    end

    context 'type declaration' do
      context 'simple enum' do
        let(:text) do
          <<~JADE.strip
            module Foo exposing (..)

            type Color = Red | Green | Blue
          JADE
        end

        it { is_expected.to include "type Color = Red | Green | Blue" }
      end

      context 'variant with args' do
        let(:text) do
          <<~JADE.strip
            module Foo exposing (..)

            type Shape = Circle(Int) | Rect(Int, Int)
          JADE
        end

        it { is_expected.to include "type Shape = Circle(Int) | Rect(Int, Int)" }
      end

      context 'with type params' do
        let(:text) do
          <<~JADE.strip
            module Foo exposing (..)

            type Maybe(a) = Just(a) | Nothing
          JADE
        end

        it { is_expected.to include "type Maybe(a) = Just(a) | Nothing" }
      end
    end

    context 'struct declaration' do
      context 'simple' do
        let(:text) do
          <<~JADE.strip
            module Foo exposing (..)

            struct Point = { x: Int, y: Int }
          JADE
        end

        it { is_expected.to include "struct Point = { x: Int, y: Int }" }
      end

      context 'with type param' do
        let(:text) do
          <<~JADE.strip
            module Foo exposing (..)

            struct Box(a) = { value: a }
          JADE
        end

        it { is_expected.to include "struct Box(a) = { value: a }" }
      end
    end

    context 'import declaration' do
      context 'simple' do
        let(:text) do
          <<~JADE.strip
            module Foo exposing (..)

            import Math.Utils
          JADE
        end

        it { is_expected.to include "import Math.Utils" }
      end

      context 'with alias' do
        let(:text) do
          <<~JADE.strip
            module Foo exposing (..)

            import Math.Utils as M
          JADE
        end

        it { is_expected.to include "import Math.Utils as M" }
      end

      context 'with exposing' do
        let(:text) do
          <<~JADE.strip
            module Foo exposing (..)

            import Math.Utils exposing (add, sub)
          JADE
        end

        it { is_expected.to include "import Math.Utils exposing (add, sub)" }
      end
    end

    context 'module' do
      context 'with exposing list' do
        let(:text) do
          <<~JADE.strip
            module Math exposing (add)

            def add(a: Int, b: Int) -> Int
              a + b
            end
          JADE
        end

        it do
          is_expected.to eql <<~JADE.strip
            module Math exposing (add)

            def add(a: Int, b: Int) -> Int
              a + b
            end
          JADE
        end
      end

      context 'with expose all' do
        let(:text) do
          <<~JADE.strip
            module Foo exposing (..)

            def bar() -> Int
              1
            end
          JADE
        end

        it do
          is_expected.to eql <<~JADE.strip
            module Foo exposing (..)

            def bar() -> Int
              1
            end
          JADE
        end
      end
    end

    context 'type annotations' do
      context 'type application' do
        let(:text) do
          <<~JADE.strip
            module Foo exposing (..)

            def wrap(x: Int) -> Maybe(Int)
              Just(x)
            end
          JADE
        end

        it { is_expected.to include "def wrap(x: Int) -> Maybe(Int)" }
      end

      context 'function type (single param)' do
        let(:text) do
          <<~JADE.strip
            def apply(f: Int -> Int, x: Int) -> Int
              f(x)
            end
          JADE
        end

        it do
          is_expected.to eql <<~JADE.strip
            def apply(f: Int -> Int, x: Int) -> Int
              f(x)
            end
          JADE
        end
      end

      context 'function type (multi param)' do
        let(:text) do
          <<~JADE.strip
            def apply(f: Int, String -> Bool, x: Int) -> Bool
              f(x, "a")
            end
          JADE
        end

        it { is_expected.to include "f: Int, String -> Bool" }
      end

      context 'record type' do
        let(:text) do
          <<~JADE.strip
            def get_name(p: { name: String, age: Int }) -> String
              p.name
            end
          JADE
        end

        it do
          is_expected.to eql <<~JADE.strip
            def get_name(p: { name: String, age: Int }) -> String
              p.name
            end
          JADE
        end
      end

      context 'tuple type' do
        let(:text) do
          <<~JADE.strip
            def fst(pair: (Int, String)) -> Int
              pair
            end
          JADE
        end

        it do
          is_expected.to eql <<~JADE.strip
            def fst(pair: (Int, String)) -> Int
              pair
            end
          JADE
        end
      end
    end

    context 'bind' do
      let(:text) do
        <<~JADE.strip
          def chain(m: Maybe(Int)) -> Maybe(Int)
            x <- m
            Just(x)
          end
        JADE
      end

      it do
        is_expected.to eql <<~JADE.strip
          def chain(m: Maybe(Int)) -> Maybe(Int)
            x <- m
            Just(x)
          end
        JADE
      end
    end

    context 'implementation' do
      context 'simple' do
        let(:text) do
          <<~JADE.strip
            module Foo exposing (..)

            implements Chainable(Maybe(a)) with
              and_then: and_then_maybe
            end
          JADE
        end

        it { is_expected.to include "implements Chainable(Maybe(a)) with" }
        it { is_expected.to include "and_then: and_then_maybe" }
        it { is_expected.to include "end" }
      end

      context 'with extends' do
        let(:text) do
          <<~JADE.strip
            module Foo exposing (..)

            implements Chainable(Maybe(a)) extends Functor with
              and_then: and_then_maybe
            end
          JADE
        end

        it { is_expected.to include "implements Chainable(Maybe(a)) extends Functor with" }
      end

      context 'lambda function' do
        let(:text) do
          <<~JADE.strip
            module Foo exposing (..)

            implements Chainable(Maybe(a)) with
              and_then: (m) -> { m }
            end
          JADE
        end

        it { is_expected.to include "and_then: (m) -> { m }" }
      end
    end

    context 'idempotency — formatting twice yields the same result' do
      let(:text) do
        <<~JADE.strip
          module Greeter exposing (greet)

          def greet(name: String) -> String
            greet_helper(name)
          end
        JADE
      end

      it 'produces stable output' do
        first_pass = subject

        second_pass =
          Lexer.tokenize(Source.new(uri: 'test', text: first_pass))
            .then { Parsing.parse(it) }
            .map { Formatter.format(it) }
            .then { it => Ok(r); r }

        expect(second_pass).to eql first_pass
      end
    end
  end
end

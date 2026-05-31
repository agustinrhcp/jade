require 'spec_helper'

require 'jade/ast'
require 'jade/parsing'
require 'jade/lexer'
require 'jade/formatter'
require 'jade/frontend/comment_attacher'

module Jade
  describe Formatter do
    let(:source) { Source.new(uri: 'test', text:) }

    subject do
      Lexer.tokenize(source)
        .then { Parsing.parse(it, source:) }
        .map { |(ast, comments)| Formatter.format(ast, comments:, source:) } => Ok(result)

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

      context 'char' do
        let(:text) { "'a'" }
        it { is_expected.to eql "'a'" }
      end
    end

    context 'variable binding and reference' do
      let(:text) do
        <<~JADE.strip
          x = 42

          x
        JADE
      end

      it { is_expected.to eql "x = 42\n\nx" }
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

      context 'with trailing comma hint' do
        let(:text) { "[1, 2, 3,]" }
        it { is_expected.to eql "[\n  1,\n  2,\n  3,\n]" }
      end
    end

    context 'tuple' do
      let(:text) { "(1, 2)" }
      it { is_expected.to eql "(1, 2)" }

      context 'three elements' do
        let(:text) { "(1, 2, 3)" }
        it { is_expected.to eql "(1, 2, 3)" }
      end

      context 'with trailing comma hint' do
        let(:text) { "(1, 2, 3,)" }
        it { is_expected.to eql "(\n  1,\n  2,\n  3,\n)" }
      end
    end

    context 'record literal' do
      context 'single field' do
        let(:text) { '{ name: "Alice" }' }
        it { is_expected.to eql '{ name: "Alice" }' }
      end

      context 'multiple fields, no trailing comma' do
        let(:text) { '{ name: "Alice", age: 30 }' }
        it { is_expected.to eql '{ name: "Alice", age: 30 }' }
      end

      context 'multiple fields with trailing comma' do
        let(:text) { '{ name: "Alice", age: 30, }' }
        it { is_expected.to eql "{\n  name: \"Alice\",\n  age: 30,\n}" }
      end
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
          x == 0 ? 1 : 2
        JADE
      end

      it do
        is_expected.to eql <<~JADE.strip
          x == 0 ? 1 : 2
        JADE
      end

      context 'nested inside a function body' do
        let(:text) do
          <<~JADE.strip
            def abs(x: Int) -> Int
              x < 0 ? 0 - x : x
            end
          JADE
        end

        it do
          is_expected.to eql <<~JADE.strip
            def abs(x: Int) -> Int
              x < 0 ? 0 - x : x
            end
          JADE
        end
      end

      context 'block form with multi-statement branches' do
        let(:text) do
          <<~JADE.strip
            def f(c: Bool) -> Int
              if c then
                x = 1
                x + 1
              else
                y = 2
                y * 3
              end
            end
          JADE
        end

        it do
          is_expected.to eql <<~JADE.strip
            def f(c: Bool) -> Int
              if c then
                x = 1
                x + 1
              else
                y = 2
                y * 3
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
            in True then 1
            in False then 0
            end
          JADE
        end

        it do
          is_expected.to eql <<~JADE.strip
            case x
            in True then 1
            in False then 0
            end
          JADE
        end
      end

      context 'wildcard pattern' do
        let(:text) do
          <<~JADE.strip
            case x
            else 0
            end
          JADE
        end

        it do
          is_expected.to eql <<~JADE.strip
            case x
            else 0
            end
          JADE
        end
      end

      context 'constructor with args' do
        let(:text) do
          <<~JADE.strip
            case m
            in Just(x) then x
            in Nothing then 0
            end
          JADE
        end

        it do
          is_expected.to eql <<~JADE.strip
            case m
            in Just(x) then x
            in Nothing then 0
            end
          JADE
        end
      end

      context 'tuple pattern' do
        let(:text) do
          <<~JADE.strip
            case pair
            in (a, b) then a
            end
          JADE
        end

        it do
          is_expected.to eql <<~JADE.strip
            case pair
            in (a, b) then a
            end
          JADE
        end
      end

      context 'record pattern' do
        let(:text) do
          <<~JADE.strip
            case p
            in { x: a, y: b } then a
            end
          JADE
        end

        it do
          is_expected.to eql <<~JADE.strip
            case p
            in { x: a, y: b } then a
            end
          JADE
        end
      end

      context 'nested case as branch body' do
        let(:text) do
          <<~JADE.strip
            def clamp(value: Int, min: Int, max: Int) -> Int
              case value < min
              in True then min
              in False
                case value > max
                in True then max
                in False then value
                end
              end
            end
          JADE
        end

        it do
          is_expected.to eql <<~JADE.strip
            def clamp(value: Int, min: Int, max: Int) -> Int
              case value < min
              in True then min
              in False
                case value > max
                in True then max
                in False then value
                end
              end
            end
          JADE
        end
      end

      context 'literal pattern' do
        let(:text) do
          <<~JADE.strip
            case n
            in 0 then "zero"
            else "other"
            end
          JADE
        end

        it do
          is_expected.to eql <<~JADE.strip
            case n
            in 0 then "zero"
            else "other"
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
            def zero -> Int
              0
            end
          JADE
        end

        it do
          is_expected.to eql <<~JADE.strip
            def zero -> Int
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

            type Color
              = Red
              | Green
              | Blue
          JADE
        end

        it { is_expected.to include "type Color\n  = Red\n  | Green\n  | Blue" }
      end

      context 'variant with args' do
        let(:text) do
          <<~JADE.strip
            module Foo exposing (..)

            type Shape
              = Circle(Int)
              | Rect(Int, Int)
          JADE
        end

        it { is_expected.to include "type Shape\n  = Circle(Int)\n  | Rect(Int, Int)" }
      end

      context 'with type params' do
        let(:text) do
          <<~JADE.strip
            module Foo exposing (..)

            type Maybe(a)
              = Just(a)
              | Nothing
          JADE
        end

        it { is_expected.to include "type Maybe(a)\n  = Just(a)\n  | Nothing" }
      end
    end

    context 'struct declaration' do
      context 'simple' do
        let(:text) do
          <<~JADE.strip
            module Foo exposing (..)

            struct Point = {
              x: Int,
              y: Int
            }
          JADE
        end

        it { is_expected.to include "struct Point = {\n  x: Int,\n  y: Int\n}" }
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

            def bar -> Int
              1
            end
          JADE
        end

        it do
          is_expected.to eql <<~JADE.strip
            module Foo exposing (..)

            def bar -> Int
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

      context 'thunk type' do
        let(:text) do
          <<~JADE.strip
            def run(f: () -> Int) -> Int
              f()
            end
          JADE
        end

        it do
          is_expected.to eql <<~JADE.strip
            def run(f: () -> Int) -> Int
              f()
            end
          JADE
        end
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

    context 'multiple bindings before return expression' do
      let(:text) do
        <<~JADE.strip
          def example(m: Maybe(Int)) -> Maybe(Int)
            a <- m
            b <- m
            a + b
          end
        JADE
      end

      it 'does not insert blank lines between bindings and return expression' do
        is_expected.to eql <<~JADE.strip
          def example(m: Maybe(Int)) -> Maybe(Int)
            a <- m
            b <- m
            a + b
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

    context 'interface declaration' do
      context 'single function' do
        let(:text) do
          <<~JADE.strip
            module Foo exposing (..)

            interface Show(a) with
              show : a -> String
            end
          JADE
        end

        it { is_expected.to include "interface Show(a) with" }
        it { is_expected.to include "  show : a -> String" }
        it { is_expected.to include "end" }
      end

      context 'multiple functions' do
        let(:text) do
          <<~JADE.strip
            module Foo exposing (..)

            interface Default(a) with
              default : a,
              alt : a -> a
            end
          JADE
        end

        it { is_expected.to include "interface Default(a) with" }
        it { is_expected.to include "  default : a" }
        it { is_expected.to include "  alt : a -> a" }
        it { is_expected.to include "end" }
      end
    end

    context 'placeholder' do
      context 'single placeholder' do
        let(:text) { "add(_, 5)" }
        it { is_expected.to eql "add(_, 5)" }
      end

      context 'multiple placeholders' do
        let(:text) { "Pair(_, _)" }
        it { is_expected.to eql "Pair(_, _)" }
      end
    end

    context 'list pattern' do
      context 'empty' do
        let(:text) do
          <<~JADE.strip
            case xs
            in [] then 0
            end
          JADE
        end

        it { is_expected.to include "in [] then 0" }
      end

      context 'cons with rest' do
        let(:text) do
          <<~JADE.strip
            case xs
            in [head | tail] then 1
            end
          JADE
        end

        it { is_expected.to include "in [head | tail] then 1" }
      end

      context 'multiple heads with rest' do
        let(:text) do
          <<~JADE.strip
            case xs
            in [a, b | rest] then 2
            end
          JADE
        end

        it { is_expected.to include "in [a, b | rest] then 2" }
      end

      context 'wildcard rest' do
        let(:text) do
          <<~JADE.strip
            case xs
            in [a | _] then 1
            end
          JADE
        end

        it { is_expected.to include "in [a | _] then 1" }
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

        second_source = Source.new(uri: 'test', text: first_pass)
        second_pass =
          Lexer.tokenize(second_source)
            .then { Parsing.parse(it, source: second_source) }
            .map { |(ast, comments)| Formatter.format(ast, comments:, source: second_source) }
            .then { it => Ok(r); r }

        expect(second_pass).to eql first_pass
      end
    end

    context 'comments' do
      context 'leading comment on an expression' do
        let(:text) { "# answer\n42" }
        it { is_expected.to eql "# answer\n42" }
      end

      context 'trailing comment on an expression' do
        let(:text) { "42 # answer" }
        it { is_expected.to eql "42 # answer" }
      end

      context 'leading comment on a function declaration' do
        let(:text) do
          <<~JADE.strip
            # Adds two integers.
            def add(a: Int, b: Int) -> Int
              a + b
            end
          JADE
        end

        it do
          is_expected.to eql <<~JADE.strip
            # Adds two integers.
            def add(a: Int, b: Int) -> Int
              a + b
            end
          JADE
        end
      end

      context 'trailing comment on a variable binding' do
        let(:text) { "x = 1 # init\nx" }
        it { is_expected.to eql "x = 1 # init\nx" }
      end

      context 'multiple leading comments' do
        let(:text) { "# first\n# second\n42" }
        it { is_expected.to eql "# first\n# second\n42" }
      end

      context 'leading comment inside a function body' do
        let(:text) do
          <<~JADE.strip
            def foo(x: Int) -> Int
              y = x + 1
              # result
              y
            end
          JADE
        end

        it do
          is_expected.to eql <<~JADE.strip
            def foo(x: Int) -> Int
              y = x + 1
              # result
              y
            end
          JADE
        end
      end

      context 'leading comment inside a case branch' do
        let(:text) do
          <<~JADE.strip
            case x
            in True
              # yes
              1
            in False then 0
            end
          JADE
        end

        it do
          is_expected.to eql <<~JADE.strip
            case x
            in True
              # yes
              1
            in False then 0
            end
          JADE
        end
      end

      context 'leading comment on a function with a qualified type name' do
        let(:text) do
          <<~JADE.strip
            # makes a date
            def today(y: Calendar.Date) -> Calendar.Date
              y
            end
          JADE
        end

        it do
          is_expected.to eql <<~JADE.strip
            # makes a date
            def today(y: Calendar.Date) -> Calendar.Date
              y
            end
          JADE
        end
      end
    end
  end
end

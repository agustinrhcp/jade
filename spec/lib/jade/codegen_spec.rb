require 'spec_helper'

require 'jade/ast'
require 'jade/frontend'
require 'jade/parsing'
require 'jade/lexer'
require 'jade/codegen'

module Jade
  describe Codegen do
    let(:source) do
      Source.new(uri: 'test', text:)
    end

    let(:generation) do
      Lexer
        .tokenize(source)
        .then { Parsing.parse(it, entry: source.uri) }
        .and_then { |(ast, _)| Frontend.run(ast) }
        .map  { Codegen.generate(*it) }
    end

    subject { generation => Ok(code); code }

    context 'an int literal' do
      let(:text) do
        <<~JADE
          42
        JADE
      end

      it { is_expected.to eql "42" }
    end

    context 'a string literal' do
      let(:text) do
        <<~JADE
          "Pepe"
        JADE
      end

      it { is_expected.to eql '"Pepe"' }
    end

    context 'a boolean literal' do
      let(:text) do
        <<~JADE
          True
        JADE
      end

      it { is_expected.to eql "true" }
    end

    context 'variable binding and reference' do
      let(:text) do
        <<~JADE
          finish = "Hei"
          spanish = "Hola"

          spanish
        JADE
      end

      it { is_expected.to eql "finish = \"Hei\"\nspanish = \"Hola\"\nspanish" }
    end

    context 'function' do
      let(:text) do
        <<~JADE
          def add(a: Int, b: Int) -> Int
            a
        JADE
      end

      it { is_expected.to eql "def add(a, b)\n  a\nend" }
    end

    context 'function call' do
      let(:text) do
        <<~JADE
          def add(a: Int, b: Int) -> Int
            a + b
          def call_add -> Int
            add(1, 2)
        JADE
      end

      it { is_expected.to include "__Test__::Internal.add(1, 2)" }
    end

    context 'type def' do
      let(:text) do
        <<~JADE
          type Maybe(a)
            = Just(a)
            | Nothing
        JADE
      end

      it 'emits Data classes with sibling-aware predicates' do
        expect(subject).to include "Just = Data.define(:_1) do\n"
        expect(subject).to include "def just?; true; end"
        expect(subject).to include "def nothing?; false; end"
        expect(subject).to include "Nothing = Data.define do\n"
      end

      context 'and reference' do
        let(:text) do
          <<~JADE
            type Maybe(a)
              = Just(a)
              | Nothing
            Just(12)
          JADE
        end

        it 'emits the constructor call after the type definitions' do
          expect(subject).to include '__Test__::Just[12]'
        end
      end
    end

    context 'qualified and unqualified references' do
      let(:text) do
        <<~JADE
          def empty?(str: String) -> Bool
            String.empty?(str)
        JADE
      end

      it { is_expected.to eql "def empty?(str)\n  str.empty?\nend" }
    end

    context 'module' do
      let(:text) do
        <<~JADE
          module Test exposing (hello)

          def hello(str: String) -> Bool
            String.empty?(str)
        JADE
      end

      it { is_expected.to include "require 'jade/runtime'\nrequire_relative 'maybe'\nrequire_relative 'result'"}

      it 'wraps function defs in Internal under the outer module' do
        is_expected.to include(
          "module Test\n" \
          "  extend self\n\n" \
          "  module Internal\n" \
          "    extend self\n\n" \
          "    def hello(str)\n" \
          "      str.empty?\n" \
          "    end\n" \
          "  end"
        )
      end

      it 'emits the boundary wrapper for eligible fns' do
        is_expected.to include("def self.hello(__p0__)")
        is_expected.to include("Jade::Interop::Boundary.decode_or_raise")
      end
    end

    context 'if then else' do
      let(:text) do
        <<~JADE
          if String.empty?("") then 1 else 2
        JADE
      end

      it { is_expected.to eql "if (\"\".empty?)\n  1\nelse\n  2\nend" }
    end

    context 'case of' do
      let(:text) do
        <<~JADE
          case 1
          of 1 -> 1
          of _ -> 2
        JADE
      end

      it { is_expected.to eql "case 1\nin 1 then 1\nin _ then 2\nend" }

      context 'with variable binding branches' do
        let(:text) do
          <<~JADE
            case 1
            of 1 -> 1
            of x -> x
          JADE
        end

        it { is_expected.to eql "case 1\nin 1 then 1\nin x then x\nend" }
      end

      context 'with constructor branches' do
        let(:text) do
          <<~JADE
            type Maybe(a)
              = Just(a)
              | Nothing
            case Just(1)
            of Nothing -> 0
            of Just(x) -> x
          JADE
        end

        it { is_expected.to include "in __Test__::Nothing then 0\nin __Test__::Just(x) then x\nend" }
      end

      context 'with record pattern' do
        let(:text) do
          <<~JADE
            case { name: "Pepe" }
            of { name: "Pepe" } -> True
            of _ -> False
          JADE
        end

        it { is_expected.to include 'in { name: "Pepe" } then true' }
      end
    end

    describe 'lambda' do
      let(:text) do
        <<~JADE
          (a, b) -> { a + b }
        JADE
      end

      it { is_expected.to eql "->(a, b) { (a + b) }" }

      context 'with a constructor pattern param' do
        let(:text) do
          <<~JADE
            type Box(a) = Box(a)

            fn = (Box(x)) -> { x }
          JADE
        end

        it { is_expected.to include "->(__p0__) {\n  __p0__ => __Test__::Box(x)\n  x\n}" }
      end

      context 'with a wildcard param' do
        let(:text) do
          <<~JADE
            (_) -> { 42 }
          JADE
        end

        it { is_expected.to eql "->(_) { 42 }" }
      end
    end

    describe 'infix and groupings' do
      let(:text) do
        <<~JADE
          1 * 2 + 3 * 4
        JADE
      end

      it { is_expected.to eql "((1 * 2) + (3 * 4))" }

      context 'with grouping' do
        let(:text) do
          <<~JADE
            1 * (2 + 3) * 4
          JADE
        end


        it { is_expected.to eql "((1 * ((2 + 3))) * 4)" }
      end
    end

    describe 'record literal' do
      let(:text) do
        <<~JADE
          {
            a: "hello",
            b: 42,
          }
        JADE
      end

      it { is_expected.to eql "Jade::Runtime.record(:a, :b)[\"hello\", 42]" }
    end

    describe 'record access' do
      let(:text) do
        <<~JADE
          {
            a: "hello",
            b: 42,
          }.a
        JADE
      end

      it { is_expected.to eql "Jade::Runtime.record(:a, :b)[\"hello\", 42].a" }
    end

    describe 'using an interop import' do
      let(:text) do
        <<~JADE
          uses Jade::Date with
            today : Task(Int, Never)
          def real_today -> Task(Int, Never)
            today()
        JADE
      end

      it 'emits a task_call with the resolved decoders' do
        expect(subject).to include 'Jade::Runtime.task_call(Jade::Date, :today,'
        expect(subject).to include "Jade::Runtime.intr('Decode.int').call()"
        expect(subject).to include 'Jade::Decode::Desc::Pass[]'
      end
    end

    describe 'struct declaration' do
      let(:text) do
        <<~JADE
          struct Person = {
            name: String,
            age: Int
          }
          Person("Guybrush", 28)
        JADE
      end

      it { is_expected.to eql "Person = Data.define(:name, :age)\n__Test__::Person[\"Guybrush\", 28]" }
    end

    describe 'tuple' do
      context 'two elements' do
        let(:text) do
          <<~JADE
            (1, 2)
          JADE
        end

        it { is_expected.to eql "Jade::Tuple::Tuple2[1, 2]" }
      end

      context 'three elements' do
        let(:text) do
          <<~JADE
            (1, 2, 3)
          JADE
        end

        it { is_expected.to eql "Jade::Tuple::Tuple3[1, 2, 3]" }
      end

      context 'four elements' do
        let(:text) do
          <<~JADE
            (1, 2, 3, 4)
          JADE
        end

        it { is_expected.to eql "Jade::Tuple::Tuple4[1, 2, 3, 4]" }
      end
    end

    describe 'stdlib with codgen as' do
      context 'with grouping' do
        let(:text) do
          <<~JADE
            not(False)
          JADE
        end


        it { is_expected.to eql "(!false)" }
      end
    end

    describe 'calling a record field that is a function' do
      let(:text) do
        <<~JADE
          record_w_fn = { some_fn: (n) -> { n + 2 } }

          record_w_fn.some_fn(1)
        JADE
      end

      it { is_expected.to eql "record_w_fn = Jade::Runtime.record(:some_fn)[->(n) { (n + 2) }]\nrecord_w_fn.some_fn.call(1)" }
    end

    describe 'eq constraint' do
      let(:text) do
        <<~JADE
          1 == 2
          False == True
        JADE
      end

      it { is_expected.to eql "(1 == 2)\n(false == true)" }

      context 'using != (free constrained function)' do
        let(:text) do
          <<~JADE
            1 != 2
          JADE
        end

        it { is_expected.to eql "(1 != 2)" }
      end

      context 'without implementation' do
        context 'for type applications' do
          let(:text) do
            <<~JADE
              def test -> Bool
                Nothing == Just(1)
            JADE
          end

          it { is_expected.to eql "def test\n  (Jade::Maybe::Nothing[] == Jade::Maybe::Just[1])\nend" }

          context 'when calling !=' do
            let(:text) do
              <<~JADE
                def test -> Bool
                  Nothing != Just(1)
              JADE
            end

            it { is_expected.to eql "def test\n  (Jade::Maybe::Nothing[] != Jade::Maybe::Just[1])\nend" }
          end

          context 'with a type with different type params per variant' do
            let(:text) do
              <<~JADE
                def test -> Bool
                  Ok("OK") != Err(404)
              JADE
            end

            it { is_expected.to eql "def test\n  (Jade::Result::Ok[\"OK\"] != Jade::Result::Err[404])\nend" }
          end
        end

        context 'for anonymous records' do
          let(:text) do
            <<~JADE
              def test -> Bool
                {
                  salute: "Hola",
                  n: 1,
                } == {
                  salute: "Hei",
                  n: 2,
                }
            JADE
          end

          it { is_expected.to eql "def test\n  (Jade::Runtime.record(:n, :salute)[1, \"Hola\"] == Jade::Runtime.record(:n, :salute)[2, \"Hei\"])\nend" }
        end
      end

      describe 'implementation' do
        context 'with an inline lambda' do
          let(:text) do
            <<~JADE
              type Pepe = Pepe(Int)
              implements Eq(Pepe) with
                (==): (pepe, other_pepe) -> { True }
            JADE
          end

          it 'emits a `==` method on the type class' do
            is_expected.to include("class ::__Test__::Pepe\n  def ==(other_pepe)\n    true\n  end\nend")
          end

          it 'emits register_impl alongside the method' do
            is_expected.to include('Jade::Runtime.register_impl("Basics.Eq"')
          end
        end

        context 'with an inline lambda that dispatches to another interface' do
          let(:text) do
            <<~JADE
              struct Person = {
                id: Int,
                name: String
              }
              implements Eq(Person) with
                (==): (one, other) -> { one.id == other.id }
            JADE
          end

          it 'emits a `==` method with operator-dispatched body' do
            is_expected.to include("class ::__Test__::Person\n  def ==(other)\n    (id == other.id)\n  end\nend")
          end

          it 'emits register_impl alongside the method' do
            is_expected.to include('Jade::Runtime.register_impl("Basics.Eq"')
          end
        end

        context 'with a function reference' do
          let(:text) do
            <<~JADE
              type Pepe = Pepe(Int)
              implements Eq(Pepe) with
                (==): eq_pepe
              def eq_pepe(one: Pepe, other: Pepe) -> Bool
                True
            JADE
          end

          it 'emits a `==` method delegating to the standalone fn' do
            is_expected.to include("class ::__Test__::Pepe\n  def ==(other)\n    ::__Test__::Internal.eq_pepe(self, other)\n  end\nend")
          end

          it 'emits register_impl alongside the method' do
            is_expected.to include('Jade::Runtime.register_impl("Basics.Eq"')
          end
        end

        context 'with a complex first-param pattern' do
          let(:text) do
            <<~JADE
              type Pepe = Pepe(Int)
              implements Eq(Pepe) with
                (==): (Pepe(x), Pepe(y)) -> { x == y }
            JADE
          end

          it 'falls back to register_impl without emitting an invalid def' do
            is_expected.not_to match(/def ==\(.*\)\n\s+__Test__::Pepe\(/)
            is_expected.to include('Jade::Runtime.register_impl("Basics.Eq"')
          end
        end
      end
    end

    describe 'comparable constraint' do
      context '(<)' do
        let(:text) { "1 < 2" }

        it { is_expected.to eql "(1 < 2)" }
      end

      context '(>)' do
        let(:text) { "1 > 2" }

        it { is_expected.to eql "(1 > 2)" }
      end

      context '(<=)' do
        let(:text) { "1 <= 2" }

        it { is_expected.to eql "(1 <= 2)" }
      end

      context '(>=)' do
        let(:text) { "1 >= 2" }

        it { is_expected.to eql "(1 >= 2)" }
      end
    end
  end
end

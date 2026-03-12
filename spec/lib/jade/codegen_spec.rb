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
        .then { Parsing.parse(it) }
        .and_then  { Frontend.run(it) }
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

      it { is_expected.to eql "finish = \"Hei\"; spanish = \"Hola\"; spanish" }
    end

    context 'function' do
      let(:text) do
        <<~JADE
          def add(a: Int, b: Int) -> Int
            a
          end
        JADE
      end

      it { is_expected.to eql "def add; ->(a, b) { a }; end" }
    end

    context 'function call' do
      let(:text) do
        <<~JADE
          def add(a: Int, b: Int) -> Int
            a + b
          end
          add(1, 2)
        JADE
      end

      it { is_expected.to eql "def add; ->(a, b) { Jade::Runtime.intr('Basics.(+)').call(a, b) }; end; __Test__.add.call(1, 2)" }
    end

    context 'type def' do
      let(:text) do
        <<~JADE
          type Maybe(a) = Just(a) | Nothing
        JADE
      end

      it { is_expected.to eql "Just = Data.define(:_1); Nothing = Data.define" }

      context 'and reference' do
        let(:text) do
          <<~JADE
            type Maybe(a) = Just(a) | Nothing
            Just(12)
          JADE
        end

        subject { super().split('; ') }
        its([0]) { is_expected.to eql "Just = Data.define(:_1)" }
        its([1]) { is_expected.to eql "Nothing = Data.define" }
        its([2]) { is_expected.to eql "__Test__::Just.method(:[]).call(12)" }
      end
    end

    context 'qualified and unqualified references' do
      let(:text) do
        <<~JADE
          def is_empty(str: String) -> Bool
            String.is_empty(str)
          end
        JADE
      end

      it { is_expected.to eql "def is_empty; ->(str) { Jade::Runtime.intr('String.is_empty').call(str) }; end" }
    end

    context 'module' do
      let(:text) do
        <<~JADE
          module Test exposing (hello)

          def hello(str: String) -> Bool
            String.is_empty(str)
          end
        JADE
      end

      it { is_expected.to include "require 'jade/runtime'; require_relative 'maybe'; require_relative 'result';"}
      it { is_expected.to include "module Test; extend self; def hello; ->(str) { Jade::Runtime.intr('String.is_empty').call(str) }; end; end" }
    end

    context 'if then else' do
      let(:text) do
        <<~JADE
          if String.is_empty("") then
            1
          else
            2
          end
        JADE
      end

      it { is_expected.to eql "if (Jade::Runtime.intr('String.is_empty').call(\"\")) then; 1; else; 2; end" }
    end

    context 'case of' do
      let(:text) do
        <<~JADE
          case 1
          of 1 then 1
          of _ then 2
          end
        JADE
      end

      it { is_expected.to eql "case 1; in 1 then 1; in _ then 2; end" }

      context 'with variable binding branches' do
        let(:text) do
          <<~JADE
            case 1
            of 1 then 1
            of x then x
            end
          JADE
        end

        it { is_expected.to eql "case 1; in 1 then 1; in x then x; end" }
      end

      context 'with constructor branches' do
        let(:text) do
          <<~JADE
            type Maybe(a) = Just(a) | Nothing
            case Just(1)
            of Nothing then 0
            of Just(x) then x
            end
          JADE
        end

        it { is_expected.to include "in __Test__::Nothing then 0; in __Test__::Just(x) then x; end" }
      end

      context 'with record pattern' do
        let(:text) do
          <<~JADE
            case { name: "Pepe" }
            of { name: "Pepe" } then True
            of _ then False
            end
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

      it { is_expected.to eql "->(a, b) { Jade::Runtime.intr('Basics.(+)').call(a, b) }" }
    end

    describe 'infix and groupings' do
      subject { super().gsub('Jade::Runtime.intr', '') }

      let(:text) do
        <<~JADE
          1 * 2 + 3 * 4
        JADE
      end

      subject { super().gsub('Jade::Runtime.intr', '') }

      it { is_expected.to eql "('Basics.(+)').call(('Basics.(*)').call(1, 2), ('Basics.(*)').call(3, 4))" }

      context 'with grouping' do
        let(:text) do
          <<~JADE
            1 * (2 + 3) * 4
          JADE
        end


        it { is_expected.to eql "('Basics.(*)').call(('Basics.(*)').call(1, (('Basics.(+)').call(2, 3))), 4)" }
      end
    end

    describe 'record literal' do
      let(:text) do
        <<~JADE
          { a: "hello", b: 42 }
        JADE
      end

      it { is_expected.to eql "Data.define(:a, :b)[\"hello\", 42]" }
    end

    describe 'record access' do
      let(:text) do
        <<~JADE
          { a: "hello", b: 42 }.a
        JADE
      end

      it { is_expected.to eql "Data.define(:a, :b)[\"hello\", 42].a" }
    end

    describe 'using an interop import' do
      let(:text) do
        <<~JADE
          uses Jade::Date with today: Int

          def real_today() -> Int
            today()
          end
        JADE
      end

      it { is_expected.to include "Jade::Runtime.guard(Jade::Date, :today, \"int\").call()" }
    end

    describe 'struct declaration' do
      let(:text) do
        <<~JADE
          struct Person = { name: String, age: Int }
          Person("Guybrush", 28)
        JADE
      end

      it { is_expected.to eql 'Person = Data.define(:name, :age); __Test__::Person.method(:[]).call("Guybrush", 28)' }
    end

    describe 'stdlib with codgen as' do
      context 'with grouping' do
        let(:text) do
          <<~JADE
            not(False)
          JADE
        end


        it { is_expected.to eql "Jade::Runtime.intr('Basics.not').call(false)" }
      end
    end
  end
end

require 'spec_helper'

require 'jade/ast'
require 'jade/frontend'
require 'jade/parser'
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
        .then { Parser.parse(it) }
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

      it { is_expected.to eql "def add; ->(a, b) { Jade::Runtime.intr('Basics.(+)').call(a, b) }; end; add.call(1, 2)" }
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
        its([2]) { is_expected.to eql "->(*args) { Just[*args] }.call(12)" }
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

      it { is_expected.to eql "require 'jade/runtime'; module Test; extend self; def hello; ->(str) { Jade::Runtime.intr('String.is_empty').call(str) }; end; end" }
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

      it { is_expected.to eql "case 1; in 1; 1; in _; 2; end" }

      context 'with variable binding branches' do
        let(:text) do
          <<~JADE
            case 1
            of 1 then 1
            of x then x
            end
          JADE
        end

        it { is_expected.to eql "case 1; in 1; 1; in x; x; end" }
      end
    end
  end
end

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

      it { is_expected.to eql "def add; ->(a, b) { (->(a, b) { a + b }).call(a, b) }; end; add.call(1, 2)" }
    end
  end
end

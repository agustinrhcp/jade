require 'spec_helper'

require 'jade/symbol'
require 'jade/frontend'
require 'jade/parser'
require 'jade/lexer'
require 'jade/ast'

module Jade
  describe Frontend do
    let(:text) do
      <<~JADE
        42
      JADE
    end

    let(:source) do
      Source.new(uri: 'test', text:)
    end

    let(:frontend) do
      Lexer
        .tokenize(source)
        .then { Parser.parse(it) }
        .and_then  { Frontend.run(it) }
    end

    subject { frontend => Ok([node, _]); node }

    it { is_expected.to be_a(AST::Node).and be_a(AST::Literal) }
    its(:symbol) { is_expected.to eql Symbol.type_ref('Basics.Int') }

    context 'with a bool' do
      let(:text) do
        <<~JADE
          False
        JADE
      end

      it { is_expected.to be_a(AST::Node).and be_a(AST::Literal) }
      its(:symbol) { is_expected.to eql Symbol.type_ref('Basics.Bool') }
    end

    context 'with a string' do
      let(:text) do
        <<~JADE
          "Pepe"
        JADE
      end

      it { is_expected.to be_a(AST::Node).and be_a(AST::Literal) }
      its(:symbol) { is_expected.to eql Symbol.type_ref('String.String') }
    end
  end
end

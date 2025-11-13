require 'spec_helper'

require 'jade/parser'
require 'jade/lexer'
require 'jade/ast'

module Jade
  describe Parser do
    let(:text) do
      <<~JADE
        42
      JADE
    end

    let(:source) do
      Source.new(uri: 'test', text:)
    end

    let(:parse) { Lexer.tokenize(source).then { Parser.parse(it) } }
    subject { parse => Ok(node); node }

    it { is_expected.to be_a(AST::Node).and be_a(AST::Literal) }
    its(:value) { is_expected.to eql 42 }

    context 'with an string literal' do
      let(:text) do
        <<~JADE
          "Hello"
        JADE
      end

      it { is_expected.to be_a(AST::Node).and be_a(AST::Literal) }
      its(:value) { is_expected.to eql "Hello" }
    end

    context 'and it is empty' do
      let(:text) do
        <<~JADE
          ""
        JADE
      end

      it { is_expected.to be_a(AST::Node).and be_a(AST::Literal) }
      its(:value) { is_expected.to eql "" }
    end

    context 'but it is malformed' do
      let(:text) do
        <<~JADE
          "Hello
        JADE
      end

      subject { parse => Err([err, _]); err }

      it { is_expected.to be_kind_of(Parser::Error) }
    end
  end
end

require 'spec_helper'

require 'jade/parser'
require 'jade/lexer'
require 'jade/ast'

module Jade
  describe Parser do
    let(:source) do
      Source.new(uri: 'test', text:)
    end

    let(:parse) { Lexer.tokenize(source).then { Parser.parse(it) } }
    subject { parse => Ok(node); node }

    context 'literals' do
      let(:text) do
        <<~JADE
          42
        JADE
      end

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

        subject { parse => Err(err); err }

        it { is_expected.to be_kind_of(Parser::Error) }
        its(:message) { is_expected.to include("Unexpected end of input, expected quote") }
      end
    end

    context 'variable binding' do
      let(:text) do
        <<~JADE
          forty_two = 42
        JADE
      end

      it { is_expected.to be_a(AST::Node).and be_a(AST::VariableBinding) }
      its(:name) { is_expected.to eql "forty_two" }
      its(:expression) { is_expected.to be_a(AST::Literal) }

      context 'when it is incomplete' do
        let(:text) do
          <<~JADE
            forty_two =
          JADE
        end

        subject { parse => Err(err); err }

        # TODO: [Parser:MultipleErrors]
        it { is_expected.to be_kind_of(Parser::Error) }
        its(:message) { is_expected.to include("expected bool") }
      end

      context 'when it is incomplete with an incomplete string' do
        let(:text) do
          <<~JADE
            forty_two = "Hello
          JADE
        end

        subject { parse => Err(err); err }

        it { is_expected.to be_kind_of(Parser::Error) }
        its(:message) { is_expected.to include("expected quote") }
      end
    end
  end
end

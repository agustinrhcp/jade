require 'spec_helper'

require 'parser'
require 'token'
require 'ast'

describe Parser do
  subject(:expression) do
    expression, _ = parser.call(Parser::State.new(tokens))
    expression
  end

  describe '|' do
    let(:tokens) do
      [
        Token.new(type: :identifier, value: "a"),
      ]
    end

    let(:parser) do
      Parser.int | Parser.identifier
    end

    it { is_expected.to eql tokens.first }
  end

  describe'chainl' do
    let(:tokens) do
      [
        Token.new(type: :int, value: 1),
        Token.new(type: :plus, value: '+'),
        Token.new(type: :int, value: 2),
        Token.new(type: :plus, value: '+'),
        Token.new(type: :int, value: 3),
      ]
    end

    let(:parser) do
      Parser.chainl(Parser.int, Parser.symbol('+'), &AST.binary)
    end

    it { is_expected.to match_ast_node(bin(bin(lit(1), :+, lit(2)), :+, lit(3))) }
  end

  describe 'many' do
    let(:tokens) do
      [
        Token.new(type: :int, value: 1),
        Token.new(type: :int, value: 2),
        Token.new(type: :int, value: 3),
      ]
    end

    let(:parser) do
      Parser.int.many
    end

    it { is_expected.to match_many_ast_nodes(lit(1), lit(2), lit(3)) }
  end

  describe '>> and map' do
    let(:parser) do
      (Parser.symbol('(') >> Parser.int >> Parser.symbol(')'))
        .map(&AST.grouping)
    end

    let(:tokens) do
      [
        Token.new(:lparen, '('),
        Token.new(:int, 42),
        Token.new(:rparen, ')'),
      ]
    end

    it { is_expected.to match_ast_node(grp(lit(42))) }
  end

  describe '.literal' do
    let(:parser) { described_class.literal }

    context 'a string' do
      let(:tokens) { [Token.new(:string, 'Hello World!')] }

      it { is_expected.to match_ast_node(lit('Hello World!')) }
    end

    context 'an int' do
      let(:tokens) { [Token.new(:int, 42)] }

      it { is_expected.to match_ast_node(lit(42)) }
    end

    context 'a boolean' do
      let(:tokens) { [Token.new(:bool, true)] }

      it { is_expected.to match_ast_node(lit(true)) }
    end
  end

  describe '.addition' do
    let(:parser) { described_class.addition }

    context 'a + 4' do
      let(:tokens) { [Token.new(:identifier, 'a'), Token.new(:plus, '+'), Token.new(:int, 4)] }

      it { is_expected.to match_ast_node(bin(var('a'), :+, lit(4))) }
    end

    context '1 * 2 + 3' do
      let(:tokens) { [Token.new(:int, 1), Token.new(:star, '*'), Token.new(:int, 2), Token.new(:plus, '+'), Token.new(:int, 3)] }

      it { is_expected.to match_ast_node(bin(bin(lit(1), :*, lit(2)), :+, lit(3))) }
    end

    context '1 + 2 * 3' do
      let(:tokens) { [Token.new(:int, 1), Token.new(:plus, '+'), Token.new(:int, 2), Token.new(:star, '*'), Token.new(:int, 3)] }

      it { is_expected.to match_ast_node(bin(lit(1), :+, bin(lit(2), :*, lit(3)))) }
    end

    context '(1 + 2) * 3' do
      let(:tokens) do
        [
          Token.new(:lparen, '('), Token.new(:int, 1), Token.new(:plus, '+'), Token.new(:int, 2), Token.new(:rparen, ')'),
          Token.new(:star, '*'), Token.new(:int, 3),
        ]
      end

      it { is_expected.to match_ast_node(bin(grp(bin(lit(1), :+, lit(2))), :*, lit(3))) }
    end
  end

  describe 'comparison' do
    let(:parser) { described_class.comparison }

    let(:tokens) do
      [
        Token.new(:int, 2), Token.new(:minus, '-'), Token.new(:int, 3),
        Token.new(:lte, '<='), Token.new(:minus, '-'), Token.new(:int, 3),
      ]
    end

    it { is_expected.to match_ast_node(bin(bin(lit(2), :-, lit(3)), :<=, uny(:-, lit(3)))) }
  end

  describe '.expression' do
    let(:parser) { described_class.expression }

    context 'handles literals' do
      context 'a string token' do
        let(:tokens) { [Token.new(:string, 'Hello World!')] }

        it { is_expected.to match_ast_node(lit('Hello World!')) }
      end
    end
  end
end

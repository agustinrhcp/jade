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
end

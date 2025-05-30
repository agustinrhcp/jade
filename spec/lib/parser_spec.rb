require 'spec_helper'

require 'parser'
require 'token'
require 'ast'

describe Parser do
  subject(:expression) do
    parser.call(Parser::State.new(tokens)) => Ok([ast, _])
    ast
  end

  describe '|' do
    let(:tokens) do
      [
        tok(:identifier, "a"),
      ]
    end

    let(:parser) do
      Parser.int | Parser.identifier
    end

    it { is_expected.to eql tokens.first }
  end

  describe '.chainl' do
    let(:tokens) do
      [
        tok(:int, 1),
        tok(:plus, '+'),
        tok(:int, 2),
        tok(:plus, '+'),
        tok(:int, 3),
      ]
    end

    let(:parser) do
      Parser.chainl(Parser.int, Parser.symbol('+'), &AST.binary)
    end

    it { is_expected.to match_ast_node(bin(bin(lit(1), :+, lit(2)), :+, lit(3))) }
  end

  describe '.int' do
    let(:parser) { described_class.int }

    context 'an int' do
      let(:tokens) { [tok(:int, 42)] }

      it { is_expected.to match_ast_node(lit(42)) }
    end
  end

  describe 'many' do
    let(:tokens) do
      [
        tok(:int, 1),
        tok(:int, 2),
        tok(:int, 3),
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
        tok(:lparen, '('),
        tok(:int, 42),
        tok(:rparen, ')'),
      ]
    end

    it { is_expected.to match_ast_node(grp(lit(42))) }
  end

  describe '.literal' do
    let(:parser) { described_class.literal }

    context 'a string' do
      let(:tokens) { [tok(:string, 'Hello World!')] }

      it { is_expected.to match_ast_node(lit('Hello World!')) }
    end

    context 'an int' do
      let(:tokens) { [tok(:int, 42)] }

      it { is_expected.to match_ast_node(lit(42)) }
    end

    context 'a boolean' do
      let(:tokens) { [tok(:bool, true)] }

      it { is_expected.to match_ast_node(lit(true)) }
    end
  end

  describe '.addition' do
    let(:parser) { described_class.addition }

    context 'a + 4' do
      let(:tokens) { [tok(:identifier, 'a'), tok(:plus, '+'), tok(:int, 4)] }

      it { is_expected.to match_ast_node(bin(var('a'), :+, lit(4))) }
    end

    context '1 * 2 + 3' do
      let(:tokens) { [tok(:int, 1), tok(:star, '*'), tok(:int, 2), tok(:plus, '+'), tok(:int, 3)] }

      it { is_expected.to match_ast_node(bin(bin(lit(1), :*, lit(2)), :+, lit(3))) }
    end

    context '1 + 2 * 3' do
      let(:tokens) { [tok(:int, 1), tok(:plus, '+'), tok(:int, 2), tok(:star, '*'), tok(:int, 3)] }

      it { is_expected.to match_ast_node(bin(lit(1), :+, bin(lit(2), :*, lit(3)))) }
    end

    context '(1 + 2) * 3' do
      let(:tokens) do
        [
          tok(:lparen, '('), tok(:int, 1), tok(:plus, '+'), tok(:int, 2), tok(:rparen, ')'),
          tok(:star, '*'), tok(:int, 3),
        ]
      end

      it { is_expected.to match_ast_node(bin(grp(bin(lit(1), :+, lit(2))), :*, lit(3))) }
    end
  end

  describe 'comparison' do
    let(:parser) { described_class.comparison }

    let(:tokens) do
      [
        tok(:int, 2), tok(:minus, '-'), tok(:int, 3),
        tok(:lte, '<='), tok(:minus, '-'), tok(:int, 3),
      ]
    end

    it { is_expected.to match_ast_node(bin(bin(lit(2), :-, lit(3)), :<=, uny(:-, lit(3)))) }
  end

  describe '.expression' do
    let(:parser) { described_class.expression }

    context 'handles literals' do
      context 'a string token' do
        let(:tokens) { [tok(:string, 'Hello World!')] }

        it { is_expected.to match_ast_node(lit('Hello World!')) }
      end
    end

    context 'errors' do
      subject(:errors) do
        parser.call(Parser::State.new(tokens)) => Err(errors)
        errors
      end

      context 'no left operator (+ 1)' do
        let(:tokens) { [tok(:plus, '+'), tok(:int, 1)] }

        it 'raises an error' do
          subject => [Parser::MissingOperandError => error, _]
          expect(error.message).to eql "Operator '+' lacks left-hand side"
        end
      end

      context 'no right side operator (1 +)' do
        let(:tokens) { [tok(:int, 1), tok(:plus, '+')] }

        it 'raises an error' do
          subject => [Parser::MissingOperandError => error, _]
          expect(error.message).to eql "Operator '+' lacks right-hand side"
        end
      end
    end
  end
end

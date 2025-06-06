require 'spec_helper'

require 'parser'
require 'token'
require 'ast'

describe Parser do
  subject(:ast) do
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

  describe '.parameter' do
    let(:parser) { described_class.parameter }

    let(:tokens) do
      [
        tok(:identifier, 'name'), tok(:colon, :':'), tok(:constant, 'Int')
      ]
    end

    it { is_expected.to match_ast_node(param('name', 'Int')) }
  end

  describe '.parameters' do
    let(:parser) { described_class.parameters }

    context 'many' do
      let(:tokens) do
        [
          tok(:identifier, 'first_name'), tok(:colon, :':'), tok(:constant, 'String'), tok(:comma, ','),
          tok(:identifier, 'last_name'), tok(:colon, :':'), tok(:constant, 'String'), tok(:comma, ','),
          tok(:identifier, 'email'), tok(:colon, :':'), tok(:constant, 'String'),
        ]
      end

      it { is_expected.to match_ast_node(params(param('first_name', 'String'), param('last_name', 'String'), param('email', 'String'))) }
    end

    context 'just one' do
      let(:tokens) do
        [
          tok(:identifier, 'email'), tok(:colon, :':'), tok(:constant, 'String'),
        ]
      end

      it { is_expected.to match_ast_node(params(param('email', 'String'))) }
    end

    context 'none' do
      let(:tokens) do
        []
      end

      it { is_expected.to match_ast_node(params) }
    end
  end

  describe '.function_declaration' do
    let(:parser) { described_class.function_declaration }
    let(:tokens) do
      [
        tok(:def, 'def'), tok(:identifier, 'double'), tok(:lparen, '('), tok(:identifier, 'n'), tok(:colon, :':'),
        tok(:constant, 'Int'), tok(:rparen, ')'), tok(:arrow, '->'), tok(:constant, 'Int'),
        tok(:let, 'let'), tok(:identifier, 'multi'), tok(:assign, '='), tok(:int, 2),
        tok(:identifier, 'n'), tok(:star, :*), tok(:identifier, 'multi'),
        tok(:end, 'end'),
      ]
    end

    it do
      is_expected.to match_ast_node(
        fn_dec('double', params(param('n', 'Int')), 'Int',
          var_dec('multi', lit(2)),
          bin(var('n'), :*, var('multi')),
        )
      )
    end
  end

  describe '.function_call' do
    let(:parser) { described_class.function_call }
    let(:tokens) { [tok(:identifier, 'double'), tok(:lparen, '('), tok(:rparen, ')')] }

    it { is_expected.to match_ast_node(fn_call('double')) }

    context 'with a single argument' do
      let(:tokens) { [tok(:identifier, 'double'), tok(:lparen, '('), tok(:int, 42), tok(:rparen, ')')] }

      it { is_expected.to match_ast_node(fn_call('double', lit(42))) }
    end

    context 'with multiple arguments' do
      let(:tokens) { [tok(:identifier, 'double'), tok(:lparen, '('), tok(:int, 42), tok(:comma, ','), tok(:identifier, 'a'), tok(:rparen, ')')] }

      it { is_expected.to match_ast_node(fn_call('double', lit(42), var('a'))) }
    end
  end

  describe '.record_declaration' do
    let(:parser) { described_class.record_declaration }
    let(:tokens) do
      [
        tok(:type, 'type'), tok(:constant, 'MyRecord'), tok(:assign, '='),
        tok(:lbrace, '{'),
        tok(:identifier, 'a'), tok(:colon, ':'), tok(:constant, 'Int'),
        tok(:rbrace, '}'),
      ]
    end

    it { is_expected.to match_ast_node(rec('MyRecord', field('a', 'Int'))) }

    context 'with many fields' do
      let(:tokens) do
        [
          tok(:type, 'type'), tok(:constant, 'MyRecord'), tok(:assign, '='),
          tok(:lbrace, '{'),
          tok(:identifier, 'a'), tok(:colon, ':'), tok(:constant, 'Int'), tok(:comma, ','),
          tok(:identifier, 'b'), tok(:colon, ':'), tok(:constant, 'String'),
          tok(:rbrace, '}'),
        ]
      end

      it { is_expected.to match_ast_node(rec('MyRecord', field('a', 'Int'), field('b', 'String'))) }
    end
  end

  describe '.record_instantiation' do
    let(:parser) { described_class.record_instantiation }
    let(:tokens) do
      [
        tok(:constant, 'MyRecord'),
        tok(:lparen, '('),
        tok(:identifier, 'a'), tok(:colon, ':'), tok(:int, 42), tok(:comma, ','),
        tok(:identifier, 'b'), tok(:colon, ':'), tok(:string, 'Alo'),
        tok(:rparen, ')'),
      ]
    end

    it { is_expected.to match_ast_node(rec_new('MyRecord', field_set('a', lit(42)), field_set('b', lit('Alo')))) }
  end

  describe '.anonymous_record' do
    let(:parser) { described_class.anonymous_record }
    let(:tokens) do
      [
        tok(:lbrace, '{'),
        tok(:identifier, 'a'), tok(:colon, ':'), tok(:int, 42), tok(:comma, ','),
        tok(:identifier, 'b'), tok(:colon, ':'), tok(:string, 'Alo'),
        tok(:rbrace, '}'),
      ]
    end

    it { is_expected.to match_ast_node(anon_rec(field_set('a', lit(42)), field_set('b', lit('Alo')))) }
  end

  describe '.statement' do
    let(:parser) { described_class.statement }

    context 'variable_declaration' do
      let(:tokens) { [tok(:let, 'let'), tok(:identifier, 'a'), tok(:assign, '='), tok(:int, 5)] }

      it { is_expected.to match_ast_node(var_dec('a', lit(5))) }

      context 'malformed' do
        subject(:errors) do
          parser.call(Parser::State.new(tokens)) => Err(errors)
          errors
        end

        describe 'let = 1' do
          let(:tokens) { [tok(:let, 'let'), tok(:assign, '='), tok(:int, 1)] }

          it 'returns an error' do
            subject => [Parser::UnexpectedTokenError => error, _]
            expect(error.message).to eql "Expected identifier, got \"=\""
          end
        end
      end
    end
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

        it 'returns an error' do
          subject => [Parser::MissingOperandError => error, _]
          expect(error.message).to eql "Operator '+' lacks left-hand side"
        end
      end

      context 'no right side operator (1 +)' do
        let(:tokens) { [tok(:int, 1), tok(:plus, '+')] }

        it 'returns an error' do
          subject => [Parser::MissingOperandError => error, _]
          expect(error.message).to eql "Operator '+' lacks right-hand side"
        end
      end
    end
  end

  context 'program' do
    let(:parser) { described_class.program }

    let(:tokens) do
      [
        tok(:let, 'let'), tok(:identifier, 'a'), tok(:assign, '='), tok(:int, 5),
        tok(:identifier, 'a'), tok(:star, '*'), tok(:int, 2),
      ]
    end

    it { is_expected.to be_a(AST::Program) }
    it do
      is_expected.to match_ast_node(prog(
        var_dec('a', lit(5)),
        bin(var('a'), :*, lit(2))
      ))
    end

    describe 'its first statement' do
      subject { ast.statements.first }
      it { is_expected.to match_ast_node(var_dec('a', lit(5))) }
    end
  end
end

require 'ast'
require 'lexer'
require 'result'

module Parser
  extend self

  def program
    (statement | expression).many.map(&AST.program)
  end

  def grouping
    (type(:lparen) >> expression >> type(:rparen))
      .map(&AST.grouping)
  end

  def expression
    equality
  end

  def statement
    variable_declaration | function_declaration
  end

  def variable_declaration
    (
      type(:let) >>
        identifier >>
        type(:assign) >>
        lazy { expression }
    ).map(&AST.variable_declaration)
  end

  def equality
    chainl(comparison, types(:eq, :not_eq), &AST.binary)
  end

  def comparison
    chainl(addition, types(:lt, :lte, :gt, :gte), &AST.binary)
  end

  def addition
    chainl(multiplicative, types(:plus, :minus), &AST.binary)
  end

  def multiplicative
    chainl(unary, types(:star, :slash), &AST.binary)
  end

  def unary
    ((types(:minus, :bang) >> lazy { unary }).map(&AST.unary)) | factor
  end

  def factor
    literal | variable| lazy { grouping }
  end

  def function_declaration
    (
      type(:def).skip >>
        identifier >>
        type(:lparen).skip >>
        parameters >>
        type(:rparen).skip >>
        type(:arrow).skip >>
        type_name >>
        lazy { (statement | expression).many.map { [it] } } >>
        type(:end).skip
    ).map(&AST.function_declaration)
  end

  def parameters
    (
      (parameter >> (type(:comma).skip >> parameter).many.map { it.flatten }) |
        none.map { [] }
    )
      .map(&AST.parameter_list)
  end

  def none
    Parser.new { |state| Ok[[nil, state]] }
  end

  def parameter
    (
      identifier >>
        type(:colon).skip >>
        type_name
    ).map(&AST.parameter)
  end

  def type_name
    identifier
  end

  def many(parser)
    Parser.new do |state|
      oks = []
      current = state

      loop do
        break if current.eof?

        case parser.call(current)
        in Ok([value, next_state])
          oks << value
          current = next_state
        in Err(err)
          break
        end
      end

      Ok[[oks, current]]
    end
  end

  def at_least_one(parser)
    parser >> many(parser)
      .map { |(first, rest)| [first] + rest }
  end

  def skip(parser)
    parser.map { |_| :skip }
  end

  def one_of(*parsers)
    Parser.new do |state|
      parsers
        .reduce(Err[[]]) do |acc, parser|
          next acc if acc.ok?

          case [acc, parser.call(state)]
          in Err, Ok(stuff) then Ok[stuff]
          in Err(errors), Err(error) then Err[errors.concat([error])]
          end
        end
        .map_error { |errors| errors.min }
    end
  end

  def |(other)
    one_of(self, other)
  end

  def chainl(value_parser, operator_parser, &combine)
    Parser.new { |state| _chainl(value_parser, operator_parser, state, &combine) }
  end

  def types(*types)
    types
      .map  { type(it) }
      .then { one_of(*it) }
  end

  def symbol(sym)
    Lexer::SYMBOLS.fetch(sym)
      .then { type(it) }
  end

  def int
    type(:int)
      .map(&AST.literal)
  end

  def bool
    type(:bool)
      .map(&AST.literal)
  end

  def string
    type(:string)
      .map(&AST.literal)
  end

  def literal
    int | bool | string
  end

  def identifier
    type(:identifier)
  end

  def variable
    identifier
      .map(&AST.variable)
  end

  def lazy(&block)
    Parser.new do |input|
      block.call.call(input)
    end
  end

  def maybe(parser, default: nil)
    Parser.new do |state|
      parser.call(state)
        .map { |(value, next_state)| [value, next_state] }
        .on_err { Ok[[default, state]] }
    end
  end

  private

  def type(type)
    Parser.new do |state|
      if state.eof?
        Err[[
          EOFError.new(
            "Unexpected end of input, expected #{type}",
            token: nil,
            position: state.position,
          ),
          state,
        ]]
      elsif state.current.type == type
        Ok[([state.current, state.advance])]
      else
        Err[[
          UnexpectedTokenError.new(
            "Expected #{type}, got #{state.current&.value.inspect}",
            token: state.current,
            position: state.position,
          ),
          state,
        ]]
      end
    end
  end

  State = Data.define(:tokens, :position) do
    def initialize(tokens:, position: 0)
      super
    end

    def current
      tokens[position]
    end

    def advance(n = 1)
      with(tokens:, position: position + n)
    end

    def eof?
      position >= tokens.length
    end
  end

  Parser = Data.define(:fn) do
    def initialize(&block)
      super(fn: block)
    end

    def call(state)
      fn.call(state)
    end

    def >>(other)
      Parser.new do |state|
        call(state).and_then do |(value1, state1)|
          other.call(state1).map do |(value2, state2)|
            [[value1, value2].reject { it == :skip }.flatten(1), state2]
          end
        end
      end
    end

    def map(&block)
      Parser.new do |state|
        call(state)
          .map { |(value, new_state)| [block.call(value), new_state] }
      end
    end

    def map_error(&block)
      Parser.new do |state|
        call(state)
          .map_error { |error| block.call(error) }
      end
    end

    def |(other)
      ::Parser.one_of(self, other)
    end

    def many
      ::Parser.many(self)
    end

    def skip
      ::Parser.skip(self)
    end
  end

  def _chainl(value_parser, operator_parser, state, &combine)
    value_parser
      .call(state)
      .map_error do |error|
        case error
        in [UnexpectedTokenError, error_state]
          [
            MissingOperandError.new(
              "Operator '#{error_state.tokens.first&.value}' lacks left-hand side",
              token: error_state.tokens.first,
              position: error_state.position,
            ),
            error_state,
          ]
        else
         error
       end
      end
      .and_then do |(left_value, current_state)|
        loop do
          operator_parser
            .call(current_state)
            .on_err { return Ok[[left_value, current_state]] } =>
              Ok([operator_token, after_op_state])

          value_parser
            .call(after_op_state)
            .on_err do |error|
              case error
              in [UnexpectedTokenError | EOFError, error_state]
                return Err[[
                  MissingOperandError.new(
                    "Operator '#{operator_token.value}' lacks right-hand side",
                    token: operator_token,
                    position: error_state.position,
                  ),
                  error_state,
                ]]
              else
                return Err[error]
              end
            end => Ok([right_value, after_right_state])

          left_value = combine.call(left_value, operator_token, right_value)
          current_state = after_right_state
        end
      end
  end

  class Error < StandardError
    attr_reader :token, :position

    def initialize(message, token:, position:)
      @token = token
      @position = position
      super(message)
    end

    protected

    def <=>(other)
      [
        semantic_priority,
        -position,
      ] <=> [
        other.semantic_priority,
        -other.position,
      ]
    end

    def semantic?
      is_a?(SemanticError)
    end

    def semantic_priority
      semantic? ? 0 : 1
    end
  end

  class UnexpectedTokenError < Error; end
  class IncompleteExpressionError < Error; end
  class EOFError < Error; end

  class SemanticError < Error; end
  class MissingOperandError < SemanticError; end
end

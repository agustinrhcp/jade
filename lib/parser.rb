require 'ast'
require 'lexer'

module Parser
  extend self

  def grouping
    (type(:lparen) >> expression >> type(:rparen))
      .map(&AST.grouping)
  end

  def expression
    equality
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

  def many(parser)
    Parser.new do |state|
      results = []
      current = state

      loop do
        result = parser.call(current)
        break unless result

        value, next_state = result
        results << value
        current = next_state
      end

      [results, current]
    end
  end

  def at_least_one(parser)
    parser >> many(parser)
      .map { |(first, rest)| [first] + rest }
  end

  def one_of(*parsers)
    Parser.new do |state|
      result = nil
      parsers.each do |parser|
        result = parser.call(state)
        break if result
      end
      result
    end
  end

  def |(other)
    one_of(self, other)
  end

  def chainl(value_parser, operator_parser, &combine)
    Parser.new do |state|
      value_result = value_parser.call(state)
      if value_result
        left_value, current_state = value_result

        loop do
          op_result = operator_parser.call(current_state)
          break unless op_result

          operator_token, after_op_state = op_result

          right_result = value_parser.call(after_op_state)
          break unless right_result

          right_value, after_right_state = right_result

          left_value = combine.call(left_value, operator_token, right_value)
          current_state = after_right_state
        end

        [left_value, current_state]
      else
        nil
      end
    end
  end

  def type(type)
    Parser.new do |state|
      next nil if state.eof?

      token = state.current
      if token.type == type
        [token, state.advance]
      else
        nil
      end
    end
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
    type_parser(:int)
      .map(&AST.literal)
  end

  def bool
    type_parser(:bool)
      .map(&AST.literal)
  end

  def string
    type_parser(:string)
      .map(&AST.literal)
  end

  def literal
    int | bool | string
  end

  def identifier
    type_parser(:identifier)
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

  private

  def type_parser(type)
    Parser.new do |state|
      next nil if state.eof?

      token = state.current
      if token.type == type
        [token, state.advance]
      else
        nil
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
        result1 = call(state)
        next nil unless result1

        value1, state1 = result1
        result2 = other.call(state1)
        next nil unless result2

        value2, state2 = result2
        [[value1, value2].flatten, state2]
      end
    end

    def map(&block)
      Parser.new do |state|
        result = call(state)
        next nil unless result

        value, new_state = result
        [block.call(value), new_state]
      end
    end

    def |(other)
      ::Parser.one_of(self, other)
    end

    def many
      ::Parser.many(self)
    end
  end
end

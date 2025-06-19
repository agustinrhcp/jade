require 'ast'
require 'lexer'
require 'result'

module Parser
  extend self

  def module
    (
      type(:module).skip >>
        (sequence(constant, separated_by: type(:dot).skip))
          .map { |tokens| tokens.map(&:value).join('.') } >>
        type(:exposing).skip >>
        type(:lparen).skip >>
        ((identifier | constant) >>
           (type(:comma).skip >> (identifier | constant)).many
        )
          .map { |(first, rest)| [[first.value] + (rest || []).map(&:value)] } >>
        type(:rparen).skip >>
        statement.many >>
        type(:end).skip
    ).map(&AST.module)
  end

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
    variable_declaration | function_declaration | record_declaration | union_type
  end

  def variable_declaration
    (
      type(:let).skip >>
        identifier >>
        type(:assign).skip >>
        lazy { expression }
    ).map(&AST.variable_declaration)
  end

  def equality
    chainl(concatenation, types(:eq, :not_eq), &AST.binary)
  end

  def concatenation
    chainl(comparison, type(:concat), &AST.binary)
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
    record_access_targets = record_instantiation | function_call | variable | lazy { grouping }

    (
      (record_access_targets >>
        (type(:dot).skip >> identifier).many)
        .map do |(target, *fields)|
          fields.flatten.reduce(target, &AST.record_access)
        end
    ) | literal
  end

  def function_declaration
    (
      type(:def).skip >>
        identifier >>
        type(:lparen).skip >>
        parameters.map { [it] } >>
        type(:rparen).skip >>
        type(:arrow).skip >>
        constant >>
        lazy { (statement | expression).many.map { [it] } } >>
        type(:end).skip
    ).map(&AST.function_declaration)
  end

  def record_declaration
    (
      type(:type).skip >>
        constant >>
        (sequence(identifier) | success([[]])).map { [it] } >>
        type(:assign).skip >>
        type(:lbrace).skip >>
        sequence(record_field, separated_by: type(:comma).skip) >>
        type(:rbrace).skip
    ).map(&AST.record_declaration)
  end

  def union_type
    (
      type(:type).skip >>
        constant >>
        (sequence(identifier) | success([[]])).map { [it] } >>
        type(:assign).skip >>
        sequence(variant, separated_by: type(:pipe).skip)
    ).map(&AST.union)
  end

  def variant
    Parser.new do |state|
      (
        type(:constant) >=
          ((type(:lparen).skip >>
          sequence((tagged_variant_field | tagged_variant_param), separated_by: type(:comma).skip) >>
          type(:rparen).skip) | none)
      )
      .and_then do |(name, *maybe_fields_or_params)|
        # TODO: This doesn't work, because there's an issue with sequence and 
        #  backtracking. 
        # TODO: This may also work if I parse just one type of param (field or param) and
        #  not support mixed, but that will requrie a workaround to show the correct
        #  and contextual error message. That workaround I may need anyways, so
        #  maybe that will be the future fix.
        fields_or_params = maybe_fields_or_params.compact

        kinds = fields_or_params.map(&:first).uniq

        case kinds
        when [:param]
          success([name, { params: fields_or_params.map(&:last).map(&AST.variant_param) }])
        when [:field]
          success([name, { fields: fields_or_params.map(&:last).map(&AST.variant_field) }])
        when []
          success([name, {}])
        else
          offending = fields_or_params.find { _1.first != kinds.first }&.last
          failure(Error.new("Mixed variant: cannot combine fields and params", token: offending, position: offending&.position || state.position), state)
        end
      end
      .map(&AST.variant)
      .call(state)
    end
  end

  def success(value)
    Parser.new { |state| Ok[[value, state]] }
  end

  def failure(error, err_state = nil)
    Parser.new { |state| Err[[error, err_state || state]] }
  end

  def tagged_variant_field
    (identifier >> type(:colon).skip >> (constant | identifier))
      .map { [[:field, it]] }
  end

  def tagged_variant_param
    (constant | identifier)
      .map { [[:param, it]] }
  end

  def record_field
    (identifier >>
      type(:colon).skip >>
      (constant.map(&AST.type_ref) | identifier.map(&AST.generic_ref))
    )
      .map(&AST.record_field)
  end

  def record_instantiation
    (
      constant >> 
        type(:lparen).skip >>
        sequence(record_field_assign, separated_by: type(:comma).skip) >>
        type(:rparen).skip
    ).map(&AST.record_instantiation)
  end

  def anonymous_record
    (
      type(:lbrace).skip >>
        sequence(record_field_assign, separated_by: type(:comma).skip) >>
        type(:rbrace).skip
    ).map(&AST.anonymous_record)
  end

  def record_field_assign
    (identifier >> type(:colon).skip >> lazy { expression }).map(&AST.record_field_assign)
  end

  def function_call
    (
      identifier >>
        type(:lparen).skip >>
        lazy { arguments } >>
        type(:rparen).skip
    ).map(&AST.function_call)
  end

  def arguments
    sequence(expression, separated_by: type(:comma).skip) |
      success([])
  end

  def parameters
    sequence(parameter, separated_by: type(:comma).skip) |
      success([])
  end

  def none
    Parser.new { |state| Ok[[nil, state]] }
  end

  def parameter
    (
      identifier >>
        type(:colon).skip >>
        constant
    ).map(&AST.parameter)
  end

  def constant
    type(:constant)
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
        in Err([err, err_state])
          current = err_state
          break
        end
      end

      Ok[[oks, current]]
    end
  end

  def sequence(parser, separated_by: none)
    (parser.map { [it] } >= (separated_by >= parser).many)
      .map { it.flatten(1) }
  end

  def at_least_one(parser, separator: nil)
    parser.map do |first|
      (separator ? separator >> parser : parser).many
        .map { |rest| [first] + rest }
    end
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
        .map_error { |errors| errors.min_by(&:first) }
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
            "Expected #{type}, got #{state.current&.type} (#{state.current&.value})",
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
          other.call(state1)
            .map do |(value2, state2)|
              [[value1, value2].reject { it == :skip }.flatten(1), state2]
            end
            .map_error do |(err, err_state)|
              [err, state]
            end
        end
      end
    end

    def >=(other)
      Parser.new do |state|
        call(state).and_then do |(value1, state1)|
          other.call(state1)
            .map do |(value2, state2)|
              [[value1, value2].reject { it == :skip }.flatten(1), state2]
            end
            .map_error do |err|
              err
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

    def and_then(&block)
      Parser.new do |state|
        call(state)
          .and_then { |(value, new_state)| block.call(value).call(new_state) }
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

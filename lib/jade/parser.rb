module Jade
  module Parser
    extend self

    def parse(tokens, parser = program)
      parser
        .call(State.new(tokens))
        .map(&:first)
        .map_error(&:first)
    end

    def program
      function_declaration | sequence(expression).map(&AST.body)
    end

    def expression
      variable_binding | variable_reference | literal
    end

    def function_declaration
      (
        type(:def) >>
          identifier >>
          type(:lparen).skip >>
          sequence(param, separated_by: type(:comma).skip).map { [it] } >>
          type(:rparen).skip >>
          type(:arrow).skip >>
          type_reference >>
          sequence(expression).map(&AST.body) >>
          type(:end)
      ).map(&AST.function_declaration)
    end

    def literal
      string | int | bool
    end

    def variable_reference
      identifier.map(&AST.variable_reference)
    end

    def param
      (
        identifier >> type(:colon).skip >> type_reference
      ).map(&AST.function_declaration_param)
    end

    def variable_binding
      (
        identifier >>
          type(:assign) >>
          (literal).map_error(&:commit)
      ).map(&AST.variable_binding)
    end

    private

    def sequence(parser, separated_by: none.skip)
      (parser.map { [it] } >> many(separated_by >> parser))
        .map { it.flatten(1) }
    end

    def none
      P.new { |state| Ok[[nil, state]] }
    end

    def skip(parser)
      parser.map { |_| :skip }
    end

    def int
      type(:int).map(&AST.literal)
    end

    def bool
      type(:bool).map(&AST.literal)
    end

    def string
      (
        type(:quote) >>
          (type(:string_chunk) >> type(:quote))
            .map_error(&:commit)
      )
        .map(&AST.string_literal)
    end

    def identifier
      type(:identifier)
    end

    def type_reference
      constant.map(&AST.type_reference)
    end

    def constant
      type(:constant)
    end

    def type(type)
      P.new do |state|
        if state.eof?
          Err[[
            EOFError.new(
              expected: type,
              position: state.position,
            ),
            state,
          ]]

        elsif state.current.type == type
          Ok[([state.current, state.advance])]

        else
          Err[[
            UnexpectedTokenError.new(
              actual: state.current,
              expected: type,
              position: state.position,
            ),
            state,
          ]]
        end
      end
    end

    def many(parser)
      P.new do |state|
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

    State = Data.define(:tokens, :position, :context_stack) do
      def initialize(tokens:, position: 0, context_stack: [])
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

    class P
      def initialize(&block)
        @fn = block
      end

      def call(tokens)
        @fn.call(tokens)
      end

      def map(&block)
        P.new do |state|
          call(state)
            .map { |(value, ok_state)| [block.call(value), ok_state] }
        end
      end

      def map_error(&block)
        P
          .new do |state|
            call(state)
              .map_error { |(err, err_state)| [block.call(err), err_state] }
          end
      end

      def |(other)
        P.new do |state|
          call(state)
            .on_err do |(error, state2)|
              if error.committed?
                Err[[error, state2]]
              else
                other.call(state)
              end
            end
        end
      end

      def >>(other)
        P.new do |state|
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

      def skip
        self.map { |_| :skip }
      end
    end

    class Error
      def initialize(position:, actual:, expected:, committed: false)
        @position = position
        @actual = actual
        @expected = expected
        @committed = committed
      end

      def committed?
        @committed
      end

      def commit
        @committed = true
        self
      end

      protected

      attr_reader :actual, :expected
    end

    class EOFError < Error
      def initialize(position:, actual: nil, expected:, committed: false)
        super
      end

      def message
        "Unexpected end of input, expected #{expected}"
      end
    end

    class UnexpectedTokenError < Error
      def initialize(position:, actual:, expected:, committed: false)
        super
      end

      def message
        "Unexpected end token #{actual}, #{expected}"
      end
    end
  end
end

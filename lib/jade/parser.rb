module Jade
  module Parser
    extend self

    def parse(tokens, parser = literal)
      parser.call(State.new(tokens))
    end

    def literal
      (type(:int) | type(:bool) | type(:string))
        .map(&AST.literal)
    end

    private

    def type(type)
      P.new do |state|
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
              "Error while parsing #{type}, got #{state.current&.type} (#{state.current&.value})",
              token: state.current,
              position: state.position,
            ),
            state,
          ]]
        end
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
        P.new { |state| call(state).map { |value, _| block.call(value) } }
      end

      def >>(other)
        P.new do |state|
          call(state)
            .and_then do |(value1, state1)|
              other
                .call(state1)
                .map do |(value2, state2)|
                  [[value1, value2].reject { it == :skip }.flatten(1), state2]
                end
                .map_error { |(err, _)| [err, tokens] }
            end
        end
      end

      def |(other)
        P.new do |state|
          call(state)
            .on_err { other.call(state) }
        end
      end
    end

    class Error
      def initialize(message, position:, token:)
        @message = message
        @position = position
        @token = token
      end
    end

    class EOFError < Error; end
    class UnexpectedTokenError < Error; end
  end
end

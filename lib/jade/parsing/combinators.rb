module Jade
  module Parsing
    module Combinators
      def grouped(parser)
        type(:lparen).skip >> parser >> type(:rparen).skip
      end

      def at_least_one(parser, separated_by: none.skip)
        parser >> ((separated_by >> sequence(parser, separated_by:)) | none.map { [] })
      end

      def sequence(parser, separated_by: none.skip)
        (parser.map { [it] } >> many(separated_by >> parser))
          .map { it.flatten(1) }
      end

      CommaList = Data.define(:items, :trailing_comma) do
        def self.empty
          new(items: [], trailing_comma: false)
        end
      end

      def comma_sequence(parser)
        P.new do |state|
          sequence(parser, separated_by: type(:comma).skip).call(state).and_then do |(items, state1)|
            if !state1.eof? && state1.current.type == :comma
              [true, state1.advance]
            else
              [false, state1]
            end
              .then { Ok[[CommaList.new(items:, trailing_comma: it[0]), it[1]]] }
          end
        end
      end

      def empty_comma_list
        none.map { CommaList.empty }
      end

      def none
        P.new { |state| Ok[[nil, state]] }
      end

      def skip(parser)
        parser.map { |_| :skip }
      end

      def many(parser)
        P.new do |state|
          oks = []
          current = state
          committed_err = nil

          loop do
            break if current.eof?

            case parser.call(current)
            in Ok([value, next_state])
              oks << value
              current = next_state
            in Err([err, err_state])
              committed_err = Err[[err, err_state]] if err.committed?
              break
            end
          end

          committed_err || Ok[[oks, current]]
        end
      end

      def type(type)
        P.new do |state|
          if state.eof?
            Err[[
              Parsing::EOFError.new(
                entry:    state.entry,
                span:     nil,
                expected: type,
              ),
              state,
            ]]

          elsif state.current.type == type
            Ok[([state.current, state.advance])]

          else
            Err[[
              Parsing::UnexpectedTokenError.new(
                entry:    state.entry,
                span:     state.current.range,
                actual:   state.current,
                expected: type,
              ),
              state,
            ]]
          end
        end
      end

      def lazy(&block)
        P.new do |input|
          block.call.call(input)
        end
      end

      State = Data.define(:tokens, :position, :entry, :context_stack) do
        def initialize(tokens:, entry:, position: 0, context_stack: [])
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

        def commit
          map_error(&:commit)
        end

        def context(name)
          map_error { |err| err.with_context(name) }
        end
      end
    end
  end
end

require 'jade/diagnostics'

module Jade
  module Parsing
    module Combinators
      module Dsl
        def parser(name, private: false, &block)
          builder = :"_build_#{name}"
          define_method(builder, &block)
          send(:private, builder)
          module_eval(<<~RUBY, __FILE__, __LINE__ + 1)
            def #{name}
              @#{name} ||= #{builder}
            end
          RUBY
          send(:private, name) if private
        end
      end
      extend Dsl

      def grouped(parser)
        type(:lparen).skip >> parser >> type(:rparen).skip
      end

      def at_least_one(parser, separated_by: none.skip)
        tail = separated_by >> sequence(parser, separated_by:)
        parser >> optional(tail, default: [])
      end

      # Consume `parser` if it matches; if not, drop the slot from the
      # surrounding `>>` tuple (no value, no failure).
      def maybe(parser)
        (parser | none).skip
      end

      # Consume `parser` if it matches; otherwise inject `default` as the
      # value. Keeps tuple arity stable in `>>` chains.
      def optional(parser, default: nil)
        parser | none.map { default }
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
        inner = sequence(parser, separated_by: type(:comma).skip)
        P.new do |state|
          inner.call(state).and_then do |(items, state1)|
            trailing, state2 =
              if !state1.eof? && state1.current.type == :comma
                [true, state1.advance]
              else
                [false, state1]
              end

            Ok[[CommaList.new(items:, trailing_comma: trailing), state2]]
          end
        end
      end

      parser(:empty_comma_list) { none.map { CommaList.empty } }

      parser(:none) { P.new { |state| Ok[[nil, state]] } }


      # Tolerant counterpart of `sequence`. Strict mode (the default) behaves
      # identically; tolerant mode records a diagnostic and resumes at the
      # next sync token instead of failing.
      def recovering_sequence(parser, sync_types:)
        P.new { recovering_step(parser, sync_types, it, []) }
      end

      def recovering_step(parser, sync_types, state, results)
        return Ok[[results, state]] if state.eof?

        case parser.call(state)
        in Ok([value, next_state])
          recovering_step(parser, sync_types, next_state, [*results, value])

        in Err([err, err_state]) unless state.tolerant
          err.committed? ? Err[[err, err_state]] : Ok[[results, state]]

        in Err([err, err_state])
          # Always advance at least one token so termination is guaranteed
          # even when sync_types isn't ahead.
          moved_past = err.committed? && err_state.position > state.position
          recovered = (moved_past ? err_state : state.advance)
            .skip_until(sync_types)
            .add_diagnostic(err.to_diagnostic)

          recovering_step(parser, sync_types, recovered, results)
        end
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
        (@types ||= {})[type] ||= P.new do |state|
          if state.eof?
            Err[[
              Parsing::EOFError.new(
                entry:    state.entry,
                span:     nil,
                expected: type,
              ),
              state,
            ]]

          elsif state.current.type == :invalid_op
            Err[[
              Parsing::InvalidOperatorError.new(
                entry:    state.entry,
                span:     state.current.range,
                actual:   state.current,
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

      State = Data.define(
        :tokens, :position, :entry, :context_stack, :tolerant, :diagnostics
      ) do
        def initialize(
          tokens:,
          entry:,
          position: 0,
          context_stack: [],
          tolerant: false,
          diagnostics: Diagnostics::List.empty
        )
          super
        end

        def current
          tokens[position]
        end

        def advance(n = 1)
          with(position: position + n)
        end

        def eof?
          position >= tokens.length
        end

        def add_diagnostic(diagnostic)
          with(diagnostics: diagnostics.add(diagnostic))
        end

        def skip_until(sync_types)
          (position...tokens.length)
            .find { sync_types.include?(tokens[it].type) }
            .then { with(position: it || tokens.length) }
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

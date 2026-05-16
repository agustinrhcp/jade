require 'jade/error'

module Jade
  module Parsing
    class Error < Jade::Error
      def initialize(entry:, span:, actual:, expected:, committed: false, context: [])
        super(entry:, span:)
        @actual    = actual
        @expected  = expected
        @committed = committed
        @context   = context
      end

      def committed?
        @committed
      end

      def commit
        @committed = true
        self
      end

      def with_context(name)
        self.class.new(
          entry:     @entry,
          span:      @span,
          actual:    @actual,
          expected:  @expected,
          committed: @committed,
          context:   [name, *@context],
        )
      end

      attr_reader :actual, :expected, :context

      protected

      def context_prefix
        return "" if @context.empty?

        "While parsing #{@context.join(' > ')}: "
      end
    end

    class EOFError < Error
      def initialize(entry:, span:, expected:, actual: nil, committed: false, context: [])
        super
      end

      def message
        "#{context_prefix}Unexpected end of input, expected #{expected}"
      end
    end

    class UnexpectedTokenError < Error
      def initialize(entry:, span:, actual:, expected:, committed: false, context: [])
        super
      end

      def hint
        return leading_pipe_hint if leading_pipe_in_type_decl?
        nil
      end

      def message
        "#{context_prefix}Unexpected token #{actual.value.inspect}, expected #{expected}#{" #{hint}" if hint}"
      end

      private

      def leading_pipe_in_type_decl?
        actual.type == :pipe &&
          expected == :constant &&
          @context.include?('type declaration')
      end

      def leading_pipe_hint
        "(leading `|` isn't supported — write `type Foo = A | B` with no `|` before the first variant)"
      end

      def label
        "unexpected #{@actual.value.inspect}"
      end
    end

    class InvalidOperatorError < Error
      HINTS = {
        '/=' => 'Use `!=` for inequality.',
      }.freeze

      def initialize(entry:, span:, actual:, expected: nil, committed: true, context: [])
        super
      end

      def hint
        HINTS[actual.value]
      end

      def message
        "#{context_prefix}Invalid operator #{actual.value.inspect}.#{" #{hint}" if hint}"
      end
    end
  end
end

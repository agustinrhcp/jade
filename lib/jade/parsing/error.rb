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

      def message
        "#{context_prefix}Unexpected token #{actual.value.inspect}, expected #{expected}"
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

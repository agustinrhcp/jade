require 'jade/error'
require 'jade/lexer'

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

      def expecting(what)
        self.class.new(
          entry:     @entry,
          span:      @span,
          actual:    @actual,
          expected:  what,
          committed: @committed,
          context:   @context,
        )
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

      # Blocks whose entries are comma-separated, so a newline between two of
      # them reads as the end of the block.
      COMMA_SEPARATED_BLOCKS = [
        'interop import declaration',
        'interface declaration',
        'implementation',
      ].freeze

      def hint
        return leading_pipe_hint if leading_pipe_in_type_decl?
        return reserved_keyword_hint if reserved_keyword_as_name?
        return colon_not_eq_hint if eq_where_colon_expected?
        return record_eq_hint if eq_where_record_pipe_expected?
        return missing_comma_hint if entry_after_unterminated_entry?
        nil
      end

      def message
        "#{context_prefix}Unexpected token #{actual.value.inspect}, expected #{expected}#{" #{hint}" if hint}"
      end

      def label
        "unexpected #{@actual.value.inspect}"
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

      def reserved_keyword_as_name?
        expected == :identifier && Jade::Lexer::KEYWORDS.include?(actual.value)
      end

      def reserved_keyword_hint
        "(`#{actual.value}` is a reserved keyword — choose a different name)"
      end

      # `=` where `:` is expected: record field, param, or annotation —
      # all written `name: value`. e.g. `{ d | f = x }` chokes on the colon.
      def eq_where_colon_expected?
        actual.type == :assign && expected == :colon
      end

      def colon_not_eq_hint
        "(use `:`, not `=`)"
      end

      # A bare `{ f = x }` literal backtracks into the record-update parser
      # and chokes on the missing `|`. The real mistake is `=` for `:`.
      def eq_where_record_pipe_expected?
        actual.type == :assign &&
          expected == :pipe &&
          !@context.include?('type declaration')
      end

      def record_eq_hint
        "(record fields use `:`, not `=` — write `{ name: value }`)"
      end

      def entry_after_unterminated_entry?
        expected == :end &&
          [:identifier, :lparen].include?(actual.type) &&
          (@context & COMMA_SEPARATED_BLOCKS).any?
      end

      def missing_comma_hint
        "(entries here are separated by `,` — add one to the line above)"
      end
    end

    # Specific case-branch shape: `in <pat> <body>` on the same source
    # line, no `then` between them. Almost always the user meant
    # `in <pat> then <body>` for an inline branch.
    class MissingThenError < Error
      def message
        "#{context_prefix}Case branch needs `then` before an inline body " \
          "(got #{@actual.value.inspect} on the same line as `in`). " \
          "Write `in <pat> then <expr>`, or put the body on the next " \
          "line for the multi-statement form."
      end

      def label
        "missing `then`"
      end
    end

    # A block that closes without producing anything: `def f -> Int end`,
    # or an `if` arm with nothing in it. Jade is expression-based, so the
    # fault is the missing body, not the terminator the parser stopped on.
    class MissingBodyError < Error
      def message
        "#{context_prefix}This body is empty — it has to produce a value " \
          "(got #{@actual.value.inspect} with nothing before it)"
      end

      def label
        'missing body'
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

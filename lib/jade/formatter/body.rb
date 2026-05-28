module Jade
  module Formatter
    module Body
      extend self
      extend Helper

      def format(node, indent:, source:)
        node => AST::Body(expressions:, dangling_comments:)

        if expressions.empty? && !dangling_comments.empty?
          dangling_comments
            .map { |tok| "#{INDENT * indent}#{tok.value}" }
            .join("\n")
        else
          join_expressions(expressions, indent, source:)
        end
      end

      private

      # Prettier-style: preserve at most one user-written blank line between
      # adjacent statements. ≥2 newlines in the source slice between them →
      # join with `\n\n`. Otherwise → `\n`. If we have no source (synthetic
      # body), fall back to single newline.
      def join_expressions(expressions, indent, source:)
        expressions
          .each_cons(2)
          .map { |prev, succ| separator_between(prev, succ, source) }
          .then { [nil, *it] }
          .zip(expressions)
          .map { |sep, expr| "#{sep}#{format_node(expr, indent:, source:)}" }
          .join
      end

      def separator_between(prev, succ, source)
        blank_line_between?(prev, succ, source) ? "\n\n" : "\n"
      end

      def blank_line_between?(prev, succ, source)
        return false unless source

        slice = source.text[prev.range.end...succ.range.begin] || ""
        # A blank line means two newlines separated only by whitespace.
        # `\n  # comment\n  ` has two newlines but content between them
        # — not a blank line.
        slice.match?(/\n[ \t]*\n/)
      end
    end
  end
end

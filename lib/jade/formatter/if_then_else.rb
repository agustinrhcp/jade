module Jade
  module Formatter
    module IfThenElse
      extend self
      extend Helper

      def format(node, indent:, source:)
        node => AST::IfThenElse(condition:, if_branch:, else_branch:)

        cond_str = format_node(condition, source:)
        try_inline_ternary(cond_str, if_branch, else_branch, indent, source:) ||
          format_block(cond_str, if_branch, else_branch, indent, source:)
      end

      # Returns nil when block form is needed: either branch is multi-
      # statement / has a leading comment, the combined line is too long,
      # or either single-expression branch already formats across multiple
      # lines (e.g. a `|>` ladder).
      def try_inline_ternary(cond_str, if_branch, else_branch, indent, source:)
        return nil if block_form?(if_branch, else_branch)

        if_str   = single_branch_expr(if_branch, source:)
        else_str = single_branch_expr(else_branch, source:)
        inline   = "#{cond_str} ? #{if_str} : #{else_str}"

        return nil if if_str.include?("\n") || else_str.include?("\n")
        return nil if too_long?(inline, indent)

        inline.then(&and_indent(indent))
      end

      def format_block(cond_str, if_branch, else_branch, indent, source:)
        [
          "if #{cond_str} then".then(&and_indent(indent)),
          format_node(if_branch, indent: indent + 1, source:),
          "else".then(&and_indent(indent)),
          format_node(else_branch, indent: indent + 1, source:),
          "end".then(&and_indent(indent)),
        ].join("\n")
      end

      # Block form needed whenever a branch has more than one expression
      # or a leading comment that the ternary form would drop.
      def block_form?(if_branch, else_branch)
        multi?(if_branch) || multi?(else_branch)
      end

      def multi?(body)
        body.expressions.length > 1 ||
          !body.leading_comments.empty? ||
          !body.expressions.first.leading_comments.empty?
      end

      # Format a body known to hold a single expression with no leading
      # comments. Called only after `block_form?` is false — the raise is
      # an invariant guard, not a user-facing error.
      def single_branch_expr(body, source:)
        raise "formatter invariant: single-expr body expected" if multi?(body)

        format_node(body.expressions.first, source:)
      end
    end
  end
end

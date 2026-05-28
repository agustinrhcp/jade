module Jade
  module Formatter
    # CaseOfBranch is invoked from CaseOf with an extra `as_else:` flag
    # — it doesn't go through the generic dispatcher, so its `format`
    # signature differs from siblings on purpose.
    module CaseOfBranch
      extend self
      extend Helper

      # Three shapes, in order of preference:
      #   - Single-expression body, fits on one line → `in <pat> then <expr>`
      #   - Single-expression body, doesn't fit / nested case / has a
      #     leading comment → `in <pat>\n  <body>` (drop `then`).
      #   - Multi-statement body → same as above.
      def format(node, indent:, source:, as_else: false)
        # `else` already conveys "wildcard inline body" — no `then` after.
        header     = as_else ? "else" : "in #{format_pattern(node.pattern)}"
        inline_sep = as_else ? "" : " then"
        body       = unwrap_grouped_case_body(node.body)
        first      = body.expressions.first
        single     = body.expressions.length == 1
        has_leading = !first.leading_comments.empty? ||
          !body.leading_comments.empty?

        multi_line = ->(child) {
          [
            header.then(&and_indent(indent)),
            format_node(child, indent: indent + 1, source:),
          ].join("\n")
        }

        return multi_line.call(first) if single && first.is_a?(AST::CaseOf)
        return multi_line.call(body) unless single && !has_leading

        first_str = format_node(first, source:)
        inline    = "#{header}#{inline_sep} #{first_str}"

        if first_str.include?("\n") || too_long?(inline, indent)
          multi_line.call(first)
        else
          inline.then(&and_indent(indent))
        end
      end

      # Strip `(case … end)` parens around a branch body. With block-form
      # `case`, the inner `end` terminates the case, so wrapping parens
      # are redundant — drop them so reformat normalises both shapes.
      def unwrap_grouped_case_body(body)
        return body unless body.expressions.length == 1

        first = body.expressions.first
        return body unless first.is_a?(AST::Grouping) &&
          first.expression.is_a?(AST::CaseOf)

        AST::Body.new(expressions: [first.expression], range: body.range)
      end
    end
  end
end

module Jade
  module Formatter
    module InfixApplication
      extend self
      extend Helper

      def format(node, indent:, source:)
        node => AST::InfixApplication(left:, operator:, right:)

        case operator.value
        when '|>'
          format_pipe_chain(node, indent, source:)
        when '++'
          format_concat_chain(node, indent, source:)
        # Spelled tight, the way it is in a pattern. `0 .. n` is nobody's
        # idea of a range.
        when '..'
          "#{format_node(left, source:)}..#{format_node(right, source:)}"
            .then(&and_indent(indent))
        else
          "#{format_node(left, source:)} #{operator.value} #{format_node(right, source:)}"
            .then(&and_indent(indent))
        end
      end

      # `|>` chains of 3 or more arms always render as a ladder; the
      # vertical shape reads as "transform stage by stage". Two-arm
      # chains stay inline unless they bust the line budget.
      def format_pipe_chain(node, indent, source:)
        chain  = collect_chain(node, '|>')
        inline = chain.map { format_node(it, source:) }.join(' |> ')

        if chain.length > 2 || too_long?(inline, indent)
          format_ladder(chain, '|>', indent, source:)
        else
          inline.then(&and_indent(indent))
        end
      end

      # `++` chains stay inline when they fit, ladder when they don't.
      def format_concat_chain(node, indent, source:)
        chain  = collect_chain(node, '++')
        inline = chain.map { format_node(it, source:) }.join(' ++ ')

        if chain.length > 1 && too_long?(inline, indent)
          format_ladder(chain, '++', indent, source:)
        else
          inline.then(&and_indent(indent))
        end
      end

      # Walk a left-associative chain and return the operands in order
      # (`a op b op c` → [a, b, c]).
      def collect_chain(node, op)
        case node
        in AST::InfixApplication(left:, operator: AST::InfixOperator(value: ^op), right:)
          collect_chain(left, op) + [right]
        else
          [node]
        end
      end

      # Emit a chain ladder: head on its own line, each subsequent
      # operand prefixed by `op` indented one level deeper.
      def format_ladder(chain, op, indent, source:)
        chain[1..]
          .map { format_node(it, source:) }
          .map { continued(it, indent + 1) }
          .map { "#{INDENT * (indent + 1)}#{op} #{it}" }
          .then { [format_node(chain.first, indent:, source:), *it] }
          .join("\n")
      end

      # What follows an operand's first line belongs under the operator that
      # introduced it, not at column zero.
      def continued(operand, indent)
        operand
          .split("\n")
          .then { |(first, *rest)| [first, *rest.map { "#{INDENT * indent}#{it}" }] }
          .join("\n")
      end
    end
  end
end

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
        else
          "#{format_node(left, source:)} #{operator.value} #{format_node(right, source:)}"
            .then(&and_indent(indent))
        end
      end

      # `|>` chains of 3 or more arms always render as a ladder; the
      # vertical shape reads as "transform stage by stage". Two-arm
      # chains stay inline.
      def format_pipe_chain(node, indent, source:)
        chain = collect_chain(node, '|>')

        if chain.length > 2
          format_ladder(chain, '|>', indent, source:)
        else
          chain
            .map { format_node(it, source:) }
            .join(' |> ')
            .then(&and_indent(indent))
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
        cont = INDENT * (indent + 1)
        head = format_node(chain.first, indent:, source:)
        tail = chain[1..].map { "#{cont}#{op} #{format_node(it, source:)}" }

        ([head] + tail).join("\n")
      end
    end
  end
end

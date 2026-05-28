module Jade
  module Formatter
    # Tuple / List share the open-sep-close shape (delegated to
    # `format_delimited`). RecordLiteral / RecordUpdate are similar but
    # carry field-shaped contents and an open-brace prelude.

    module Tuple
      extend self
      extend Helper

      def format(node, indent:, source:)
        node => AST::Tuple(items:, trailing_comma:)

        format_delimited(
          items.map { format_node(it, source:) },
          '(', ')', trailing_comma, indent,
        )
      end
    end

    module List
      extend self
      extend Helper

      def format(node, indent:, source:)
        node => AST::List(items:, trailing_comma:)

        format_delimited(
          items.map { format_node(it, source:) },
          '[', ']', trailing_comma, indent,
        )
      end
    end

    module RecordLiteral
      extend self
      extend Helper

      def format(node, indent:, source:)
        node => AST::RecordLiteral(fields:, trailing_comma:)

        field_strs = fields.map { "#{it.key}: #{format_node(it.value, source:)}" }
        inline     = "{ #{field_strs.join(', ')} }"

        if trailing_comma || too_long?(inline, indent)
          inner = field_strs
            .map { "#{it.then(&and_indent(indent + 1))}," }
            .join("\n")
          "#{INDENT * indent}{\n#{inner}\n#{INDENT * indent}}"
        else
          inline.then(&and_indent(indent))
        end
      end
    end

    module RecordUpdate
      extend self
      extend Helper

      def format(node, indent:, source:)
        node => AST::RecordUpdate(base:, fields:, trailing_comma:)

        base_str   = format_node(base, source:)
        field_strs = fields.map { "#{it.key}: #{format_node(it.value, source:)}" }
        inline     = "{ #{base_str} | #{field_strs.join(', ')} }"

        if trailing_comma || too_long?(inline, indent)
          inner = field_strs
            .map { "#{it.then(&and_indent(indent + 1))}," }
            .join("\n")
          "#{INDENT * indent}{ #{base_str} |\n#{inner}\n#{INDENT * indent}}"
        else
          inline.then(&and_indent(indent))
        end
      end
    end
  end
end

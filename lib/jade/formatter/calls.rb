module Jade
  module Formatter
    # FunctionCall and KeyedCall share the same break-on-too-long /
    # respect-trailing-comma logic. Grouped here as siblings.

    module FunctionCall
      extend self
      extend Helper

      def format(node, indent:, source:)
        node => AST::FunctionCall(callee:, args:, trailing_comma:)

        callee_str = format_node(callee, source:)
        args_strs  = args.map { format_node(it, source:) }
        Calls.render(callee_str, args_strs, trailing_comma, indent)
      end
    end

    module KeyedCall
      extend self
      extend Helper

      def format(node, indent:, source:)
        node => AST::KeyedCall(callee:, fields:, trailing_comma:)

        callee_str = format_node(callee, source:)
        field_strs = fields.map { "#{it.key}: #{format_node(it.value, source:)}" }
        Calls.render(callee_str, field_strs, trailing_comma, indent)
      end
    end

    module Calls
      extend self
      extend Helper

      def render(callee_str, item_strs, trailing_comma, indent)
        inline = "#{callee_str}(#{item_strs.join(', ')})"

        if trailing_comma || too_long?(inline, indent)
          inner = item_strs
            .map { "#{it.then(&and_indent(indent + 1))}," }
            .join("\n")

          "#{callee_str.then(&and_indent(indent))}(\n#{inner}\n#{INDENT * indent})"
        else
          inline.then(&and_indent(indent))
        end
      end
    end
  end
end

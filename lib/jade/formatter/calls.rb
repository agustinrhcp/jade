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

        Calls.render(
          callee_str, args_strs, trailing_comma, indent, opened_last: Calls.opened(args.last, source)
        )
      end
    end

    module KeyedCall
      extend self
      extend Helper

      def format(node, indent:, source:)
        node => AST::KeyedCall(callee:, fields:, trailing_comma:)

        callee_str = format_node(callee, source:)
        field_strs = fields.map { "#{it.key}: #{format_node(it.value, source:)}" }

        Calls.render(
          callee_str, field_strs, trailing_comma, indent,
          opened_last: Calls.opened_field(fields.last, source),
        )
      end
    end

    module Calls
      extend self
      extend Helper

      # A trailing block-shaped argument reads as the call's body, the way a
      # Ruby block does. Only these three grow a body worth hugging.
      HUGGABLE = [AST::Lambda, AST::List, AST::RecordLiteral].freeze

      def huggable?(node)
        HUGGABLE.any? { node.is_a?(it) }
      end

      def opened(node, source)
        return nil unless huggable?(node)

        dispatch_for(node).format(node, indent: 0, source:, open: true)
      end

      def opened_field(field, source)
        opened(field&.value, source)&.then { "#{field.key}: #{it}" }
      end

      def render(callee_str, item_strs, trailing_comma, indent, opened_last: nil)
        case [trailing_comma, inline(callee_str, item_strs, indent), opened_last]
        in [false, String => fits, _] then fits
        in [false, nil, String => last] then hug(callee_str, item_strs, last, indent)
        else exploded(callee_str, item_strs, indent)
        end
      end

      private

      def inline(callee_str, item_strs, indent)
        "#{callee_str}(#{item_strs.join(', ')})"
          .then { too_long?(it, indent) ? nil : it.then(&and_indent(indent)) }
      end

      def hug(callee_str, item_strs, last, indent)
        hug_last(callee_str, item_strs, last, indent) ||
          exploded(callee_str, item_strs, indent)
      end

      # An earlier multi-line argument would leave the head straddling lines.
      def hug_last(callee_str, item_strs, last, indent)
        case [item_strs[..-2], last.split("\n")]
        in [[*head], [_]] then nil
        in [[*head], _] if head.any? { it.include?("\n") } then nil
        in [[*head], [opener, *rest]]
          "#{callee_str}(#{(head + [opener]).join(', ')}"
            .then { too_long?(it, indent) ? nil : hugged_lines(it, rest, indent) }
        end
      end

      def hugged_lines(opening, rest, indent)
        [opening, *rest[..-2], "#{rest.last})"]
          .join("\n")
          .then(&and_indent(indent))
      end

      def exploded(callee_str, item_strs, indent)
        item_strs
          .map { "#{it.then(&and_indent(indent + 1))}," }
          .join("\n")
          .then { "#{callee_str.then(&and_indent(indent))}(\n#{it}\n#{INDENT * indent})" }
      end
    end
  end
end

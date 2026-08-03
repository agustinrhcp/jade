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

        Calls::Call[callee_str, args_strs, indent].then do |call|
          Calls.render(call, trailing_comma, opened_last: Calls.render_open(args.last, source))
        end
      end
    end

    module KeyedCall
      extend self
      extend Helper

      def format(node, indent:, source:)
        node => AST::KeyedCall(callee:, fields:, trailing_comma:)

        callee_str = format_node(callee, source:)
        field_strs = fields.map { "#{it.key}: #{format_node(it.value, source:)}" }

        Calls::Call[callee_str, field_strs, indent].then do |call|
          Calls.render(call, trailing_comma, opened_last: Calls.render_open_field(fields.last, source))
        end
      end
    end

    module Calls
      extend self
      extend Helper

      # A trailing block-shaped argument reads as the call's body, the way a
      # Ruby block does. Only these three grow a body worth hugging.
      HUGGABLE = [AST::Lambda, AST::List, AST::RecordLiteral].freeze

      # A rendered call, before the decision of how to lay it out: the callee,
      # its already-formatted arguments, and the column they sit at.
      Call = Data.define(:callee, :items, :indent)

      def huggable?(node)
        HUGGABLE.any? { node.is_a?(it) }
      end

      def render_open(node, source)
        return nil unless huggable?(node)

        dispatch_for(node).format(node, indent: 0, source:, open: true)
      end

      def render_open_field(field, source)
        render_open(field&.value, source)&.then { "#{field.key}: #{it}" }
      end

      def render(call, trailing_comma, opened_last: nil)
        case [trailing_comma, inline(call), opened_last]
        in [false, String => fits, _] then fits
        in [false, nil, String => last] then hug_last(call, last) || explode(call)
        else explode(call)
        end
      end

      private

      def inline(call)
        "#{call.callee}(#{call.items.join(', ')})"
          .then { too_long?(it, call.indent) ? nil : it.then(&and_indent(call.indent)) }
      end

      # An earlier multi-line argument would leave the head straddling lines.
      def hug_last(call, last)
        case [call.items[..-2], last.split("\n")]
        in [[*head], [_]] then nil
        in [[*head], _] if head.any? { it.include?("\n") } then nil
        in [[*head], [opener, *rest]]
          "#{call.callee}(#{(head + [opener]).join(', ')}"
            .then { too_long?(it, call.indent) ? nil : hug_lines(it, rest, call.indent) }
        end
      end

      def hug_lines(opening, rest, indent)
        [opening, *rest[..-2], "#{rest.last})"]
          .join("\n")
          .then(&and_indent(indent))
      end

      def explode(call)
        call.items
          .map { "#{it.then(&and_indent(call.indent + 1))}," }
          .join("\n")
          .then { "#{indent_callee(call)}(\n#{it}\n#{INDENT * call.indent})" }
      end

      def indent_callee(call)
        call.callee.then(&and_indent(call.indent))
      end
    end
  end
end

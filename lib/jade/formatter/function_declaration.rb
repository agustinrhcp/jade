module Jade
  module Formatter
    module FunctionDeclaration
      extend self
      extend Helper

      def format(node, indent:, source:)
        node => AST::FunctionDeclaration(
          name:, params:, return_type:, body:
        )

        [
          format_signature(name, params, return_type, indent, source:),
          format_node(body, indent: indent + 1, source:),
          "end".then(&and_indent(indent)),
        ].join("\n")
      end

      private

      # `def name(params) -> Return`. When the inline form is too long:
      #   - if return is a breakable record, break the record (params stay
      #     inline when the resulting header fits).
      #   - else if there are params, break params multi-line with
      #     `-> Type` on the close-paren line.
      #   - else live with the long line.
      def format_signature(name, params, return_type, indent, source:)
        return_str    = format_type_atom(return_type)
        params_inline = format_params_inline(params, source:)
        inline        = "def #{name}#{params_inline} -> #{return_str}"

        return inline.then(&and_indent(indent)) unless too_long?(inline, indent)

        broken_record = try_break_record_return(name, params_inline, return_type, indent)
        return broken_record if broken_record

        return inline.then(&and_indent(indent)) if params.empty?

        format_params_multi(name, params, return_str, indent, source:)
      end

      def format_params_inline(params, source:)
        return "" if params.empty?

        params.map { format_node(it, source:) }.join(", ").then { "(#{it})" }
      end

      def try_break_record_return(name, params_inline, return_type, indent)
        return nil unless Type.breakable_record?(return_type)

        record_multi = Type.format_record_multiline(return_type, indent)
        header = "def #{name}#{params_inline} -> #{record_multi.lines.first.chomp}"
        return nil if too_long?(header, indent)

        "def #{name}#{params_inline} -> #{record_multi}"
          .then(&and_indent(indent))
      end

      def format_params_multi(name, params, return_str, indent, source:)
        params_lines = params
          .map { "#{format_node(it, source:)},".then(&and_indent(indent + 1)) }
          .join("\n")

        [
          "def #{name}(".then(&and_indent(indent)),
          params_lines,
          ") -> #{return_str}".then(&and_indent(indent)),
        ].join("\n")
      end
    end
  end
end

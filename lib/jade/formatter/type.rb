module Jade
  module Formatter
    module Type
      extend self
      extend Helper

      def format(node)
        case node
        in AST::TypeName(type:)
          type

        in AST::QualifiedTypeName(path:)
          path.join(".")

        in AST::TypeVar(type:)
          type

        in AST::TypeApplication(constructor:, args:)
          if args.empty?
            format(constructor)
          else
            args
              .map { format(it) }
              .join(', ')
              .then { "#{format(constructor)}(#{it})" }
          end

        in AST::TypeFunction(params:, return_type:)
          params_str = params.empty? ?
            "()" :
            params.map { format_atom(it) }.join(', ')

          "#{params_str} -> #{format_atom(return_type)}"

        in AST::TypeRecord(fields:, row_var:)
          fields_str = fields.map { |k, v| "#{k}: #{format(v)}" }.join(", ")
          row_prefix = row_var ? "#{row_var.name} | " : ""

          "{ #{row_prefix}#{fields_str} }"

        in AST::TypeTuple(items:)
          items.map { format(it) }.join(', ').then { "(#{it})" }
        end
      end

      # Wrap a function type in `(...)` so nested arrows stay unambiguous —
      # the type parser only accepts a `type_atom` on either side of `->`.
      def format_atom(node)
        node.is_a?(AST::TypeFunction) ? "(#{format(node)})" : format(node)
      end

      def breakable_record?(type)
        type.is_a?(AST::TypeRecord) && type.fields.size > 1
      end

      def format_record_multiline(type, indent)
        type => AST::TypeRecord(fields:, row_var:)
        open = row_var ? "{ #{row_var.name} |" : "{"
        fields_str = fields
          .map { |k, v| "#{k}: #{format(v)},".then(&and_indent(indent + 1)) }
          .join("\n")

        "#{open}\n#{fields_str}\n#{INDENT * indent}}"
      end
    end
  end
end

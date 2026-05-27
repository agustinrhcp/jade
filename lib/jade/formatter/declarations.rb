module Jade
  module Formatter
    # Top-level declaration nodes other than `def` (which lives in its
    # own file because of the signature break logic).

    module TypeDeclaration
      extend self
      extend Helper

      def format(node, indent:, source:)
        node => AST::TypeDeclaration(name:, type_params:, variants:)

        params_str = type_params.empty? ?
          "" :
          "(#{type_params.map(&:name).join(', ')})"
        header = "type #{name}#{params_str}"

        if variants.size == 1
          "#{header} = #{format_node(variants.first, source:)}"
            .then(&and_indent(indent))
        else
          inner = INDENT * (indent + 1)
          variants_str = variants
            .map { format_node(it, source:) }
            .map.with_index { |v, i| "#{inner}#{i == 0 ? '=' : '|'} #{v}" }
            .join("\n")

          "#{and_indent(indent).call(header)}\n#{variants_str}"
        end
      end
    end

    module VariantDeclaration
      extend self
      extend Helper

      def format(node, indent:, source:)
        node => AST::VariantDeclaration(name:, args:)

        case args
        in nil | []
          name

        in [AST::TypeRecord(fields:, row_var: nil)]
          fields
            .map { |k, v| "#{k}: #{format_type(v)}" }
            .join(', ')
            .then { "#{name}(#{it})" }

        else
          args
            .map { format_type(it) }
            .join(', ')
            .then { "#{name}(#{it})" }
        end
      end
    end

    module StructDeclaration
      extend self
      extend Helper

      def format(node, indent:, source:)
        node => AST::StructDeclaration(name:, type_params:, record_type:)

        params_str = type_params.empty? ?
          "" :
          "(#{type_params.map(&:name).join(', ')})"
        header = "struct #{name}#{params_str} ="

        record_type => AST::TypeRecord(fields:, row_var:)

        if fields.size > 1
          format_multiline(header, fields, row_var, indent)
        else
          "#{header} #{format_type(record_type)}".then(&and_indent(indent))
        end
      end

      def format_multiline(header, fields, row_var, indent)
        open_brace = row_var ? "{ #{row_var.name} |" : "{"
        fields_str = fields
          .map { |k, v| "#{k}: #{format_type(v)}".then(&and_indent(indent + 1)) }
          .join(",\n")

        and_indent(indent)
          .call("#{header} #{open_brace}")
          .then { "#{it}\n#{fields_str}\n#{INDENT * indent}}" }
      end
    end

    module TypeAliasDeclaration
      extend self
      extend Helper

      def format(node, indent:, source:)
        node => AST::TypeAliasDeclaration(name:, type_params:, body_type:)

        params_str = type_params.empty? ?
          "" :
          "(#{type_params.map(&:name).join(', ')})"

        "type alias #{name}#{params_str} = #{format_type(body_type)}"
          .then(&and_indent(indent))
      end
    end

    module ImportDeclaration
      extend self
      extend Helper

      def format(node, indent:, source:)
        node => AST::ImportDeclaration(module_name:, as:, exposing:)

        parts = ["import #{module_name}"]
        parts << "as #{as.as}" if as
        parts << format_exposing(exposing) unless exposing in AST::ExposeNone | nil

        parts.join(' ').then(&and_indent(indent))
      end
    end

    module InteropImportDeclaration
      extend self
      extend Helper

      def format(node, indent:, source:)
        node => AST::InteropImportDeclaration(module: interop_module, functions:)

        funcs_str = functions
          .map { format_node(it, source:).then(&and_indent(indent + 1)) }
          .join(",\n")

        [
          "uses #{interop_module.name} with".then(&and_indent(indent)),
          funcs_str,
          "end".then(&and_indent(indent)),
        ].join("\n")
      end
    end

    module InterfaceDeclaration
      extend self
      extend Helper

      def format(node, indent:, source:)
        node => AST::InterfaceDeclaration(name:, type_param:, functions:)

        fns_str = functions
          .map { format_node(it, indent: indent + 1, source:) }
          .join(",\n")

        [
          "interface #{name}(#{type_param.name}) with".then(&and_indent(indent)),
          fns_str,
          "end".then(&and_indent(indent)),
        ].join("\n")
      end
    end

    module Implementation
      extend self
      extend Helper

      def format(node, indent:, source:)
        node => AST::Implementation(interface:, applied_type:, extends:, functions:)

        extends_str = extends.empty? ? "" : " extends #{extends.join(', ')}"
        header = "implements #{interface}(#{format_type(applied_type)})" \
          "#{extends_str} with"
        fns_str = functions
          .map { format_node(it, indent: indent + 1, source:) }
          .join(",\n")

        [
          header.then(&and_indent(indent)),
          fns_str,
          "end".then(&and_indent(indent)),
        ].join("\n")
      end
    end

    module ImplementationFunction
      extend self
      extend Helper

      def format(node, indent:, source:)
        node => AST::ImplementationFunction(name:, fn:)

        "#{name}: #{format_node(fn, source:)}".then(&and_indent(indent))
      end
    end
  end
end

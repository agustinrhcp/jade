require 'uri'

module Jade
  module LSP
    module Converters
      extend self

      # Byte offsets, not UTF-16 code units. Matches the `utf-8` position
      # encoding negotiated at initialize; under the default `utf-16`,
      # columns drift right by N for each multi-byte char on the line.
      def offset_to_position(source, offset)
        line = source.line_starts.rindex { it <= offset } || 0
        { line:, character: offset - source.line_starts[line] }
      end

      def position_to_offset(source, line, character)
        source.line_starts[line] + character
      end

      def span_to_range(source, span)
        {
          start: offset_to_position(source, span.begin),
          end:   offset_to_position(source, span.end),
        }
      end

      SEVERITY = { error: 1, warning: 2, info: 3, hint: 4 }.freeze

      SYMBOL_KIND = {
        function: 12,
        enum: 10,
        enum_member: 22,
        struct: 23,
        interface: 11,
      }.freeze

      HOVERABLE_SYMBOLS = [
        Jade::Symbol::Function,
        Jade::Symbol::StdlibFunction,
        Jade::Symbol::InteropFunction,
        Jade::Symbol::InterfaceFunction,
        Jade::Symbol::Constructor,
        Jade::Symbol::Variant,
      ].freeze

      def hover_for_path(path, registry)
        symbol = path
          .reverse
          .filter_map { hoverable_symbol(it, registry) }
          .first

        return nil unless symbol

        type, _ = Jade::Type
          .from_symbol(symbol, registry, Frontend::TypeChecking::VarGen.new)

        {
          contents: {
            kind: 'markdown',
            value: "```jade\n#{symbol.name} : #{type}\n```",
          },
        }
      rescue StandardError
        nil
      end

      def to_document_symbol(node, source)
        case node
        in AST::FunctionDeclaration(name:, range:)
          document_symbol(name, :function, source, range)

        in AST::TypeDeclaration(name:, range:, variants:)
          document_symbol(
            name, :enum, source, range,
            children: variants.map { document_symbol(it.name, :enum_member, source, it.range) },
          )

        in AST::StructDeclaration(name:, range:)
          document_symbol(name, :struct, source, range)

        in AST::InterfaceDeclaration(name:, range:, functions:)
          document_symbol(
            name, :interface, source, range,
            children: functions.map { document_symbol(it.name, :function, source, it.range) },
          )

        else
          nil
        end
      end

      def diagnostic_to_lsp(diagnostic)
        {
          range: diagnostic.primary.then { span_to_range(it.source, it.span) },
          severity: SEVERITY.fetch(diagnostic.severity, 3),
          source: 'jade',
          message: diagnostic_message(diagnostic),
        }
      end

      def relative_path(uri, source_root)
        uri
          .sub(%r{\Afile://}, '')
          .then { URI::DEFAULT_PARSER.unescape(it) }
          .then { Pathname.new(it).relative_path_from(Pathname.new(source_root)).to_s }
      end

      def lsp_uri(relative_path, source_root)
        File
          .expand_path(File.join(source_root, relative_path))
          .then { URI::DEFAULT_PARSER.escape(it) }
          .then { "file://#{it}" }
      end

      private

      def hoverable_symbol(node, registry)
        case node
        in AST::VariableReference | AST::ConstructorReference | AST::QualifiedAccess
          resolved = node.symbol.is_a?(Jade::Symbol::ValueRef) ? registry.lookup(node.symbol) : node.symbol
          HOVERABLE_SYMBOLS.include?(resolved.class) ? resolved : nil
        else
          nil
        end
      end

      def document_symbol(name, kind, source, range, children: [])
        {
          name: name.to_s,
          kind: SYMBOL_KIND.fetch(kind),
          range: span_to_range(source, range),
          selectionRange: span_to_range(source, range),
          children:,
        }
      end

      def diagnostic_message(diagnostic)
        [diagnostic.message, *diagnostic.annotations.map { "#{it.kind}: #{it.message}" }]
          .join("\n")
      end
    end
  end
end

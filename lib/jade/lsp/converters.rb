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
        Jade::Symbol::Union,
        Jade::Symbol::Struct,
      ].freeze

      # LSP CompletionItemKind values we use.
      COMPLETION_KIND_SNIPPET = 15
      # LSP InsertTextFormat: 1 = PlainText, 2 = Snippet (with tab stops).
      INSERT_FORMAT_SNIPPET = 2

      def definition_for_path(path, registry, entry, source_root)
        innermost_resolved(path, registry, entry)
          .then { definition_location(it, registry, source_root) }
      end

      def hover_for_path(path, registry, entry)
        path
          .reverse
          .lazy
          .filter_map { hover_for_node(it, registry, entry) }
          .first
      rescue StandardError
        nil
      end

      def completion_items
        Snippets::ALL.map do |snippet|
          {
            label: snippet.label,
            kind: COMPLETION_KIND_SNIPPET,
            detail: snippet.detail,
            insertText: snippet.body,
            insertTextFormat: INSERT_FORMAT_SNIPPET,
          }
        end
      end

      def references_for_path(
        path, registry, entry, source_root, include_declaration:
      )
        symbol = innermost_resolved(path, registry, entry)
        return nil unless symbol

        refs = usage_locations(symbol, registry, source_root)
        return refs unless include_declaration

        refs + declaration_locations(symbol, registry, source_root)
      end

      def to_document_symbol(node, source)
        case node
        in AST::FunctionDeclaration(name:, range:)
          document_symbol(name, :function, source, range)

        in AST::TypeDeclaration(name:, range:, variants:)
          document_symbol(
            name, :enum, source, range,
            children: variants.map { variant_symbol(it, source) },
          )

        in AST::StructDeclaration(name:, range:)
          document_symbol(name, :struct, source, range)

        in AST::InterfaceDeclaration(name:, range:, functions:)
          document_symbol(
            name, :interface, source, range,
            children: functions.map { interface_fn_symbol(it, source) },
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
          .then { Pathname.new(it) }
          .then { it.relative_path_from(Pathname.new(source_root)) }
          .then { it.to_s }
      end

      def lsp_uri(relative_path, source_root)
        File
          .expand_path(File.join(source_root, relative_path))
          .then { URI::DEFAULT_PARSER.escape(it) }
          .then { "file://#{it}" }
      end

      private

      def definition_location(symbol, registry, source_root)
        return nil unless symbol&.respond_to?(:decl_span) && symbol.decl_span

        registry
          .modules
          .fetch(symbol.module_name)
          .source
          .then { build_location(it, symbol.decl_span, source_root) }
      end

      def usage_locations(symbol, registry, source_root)
        registry
          .modules
          .each_value
          .flat_map do |entry|
            next [] unless entry.source && entry.usage_index

            entry
              .usage_index
              .for(symbol)
              .map { build_location(entry.source, it.range, source_root) }
          end
      end

      def declaration_locations(symbol, registry, source_root)
        definition_location(symbol, registry, source_root)
          .then { it ? [it] : [] }
      end

      def build_location(source, span, source_root)
        {
          uri: lsp_uri(source.uri, source_root),
          range: span_to_range(source, span),
        }
      end

      def hoverable?(symbol)
        symbol && HOVERABLE_SYMBOLS.include?(symbol.class)
      end

      # Symbol-based hover (richer — signatures, constraints, impls) is
      # tried first; pinned-type hover (from TypeChecking's per-node
      # table) is the fallback for nodes that don't resolve to a named
      # symbol (locals, intermediate expressions).
      def hover_for_node(node, registry, entry)
        symbol = resolve_symbol(node, registry, entry)
        return hover_response(symbol, registry) if hoverable?(symbol)

        type = entry.env.node_types[node.id]
        return nil unless type

        { contents: { kind: 'markdown', value: code_block(pinned_text(node, type)) } }
      end

      def pinned_text(node, type)
        node.respond_to?(:name) && node.name.is_a?(String) ?
          "#{node.name} : #{type}" :
          type.to_s
      end

      def hover_response(symbol, registry)
        hover_body(symbol, registry)
          .then { { contents: { kind: 'markdown', value: code_block(it) } } }
      end

      def hover_body(symbol, registry)
        case symbol
        in Jade::Symbol::Union | Jade::Symbol::Struct
          render_type(symbol, registry)
        else
          render_value(symbol, registry)
        end
      end

      def code_block(body)
        "```jade\n#{body}\n```"
      end

      # For Symbol::Function we prefer the Scheme stored in the defining
      # module's env — that's where inferred constraints (e.g. `Eq a`
      # picked up from `==`) live. Falls back to Type.from_symbol for
      # symbol kinds whose constraints surface directly on the symbol.
      def render_value(symbol, registry)
        type_and_constraints(symbol, registry)
          .then { |(t, cs)| render_signature(symbol.name, t, cs) }
      end

      def type_and_constraints(symbol, registry)
        scheme = symbol.is_a?(Jade::Symbol::Function) &&
                 lookup_scheme(symbol, registry)
        return [scheme.type, scheme.constraints] if scheme

        Jade::Type.from_symbol(
          symbol, registry, Frontend::TypeChecking::VarGen.new
        )
      end

      def render_type(symbol, registry)
        impls_for(symbol, registry)
          .then { it.empty? ? '' : "\n\nimplements #{it.join(', ')}" }
          .then { "#{type_kind(symbol)} #{symbol.name}#{it}" }
      end

      def type_kind(symbol)
        symbol.is_a?(Jade::Symbol::Union) ? 'type' : 'struct'
      end

      def impls_for(type_symbol, registry)
        registry
          .implementations
          .keys
          .select { it[1] == type_symbol.qualified_name }
          .map { it[0].split('.').last }
          .uniq
      end

      def lookup_scheme(symbol, registry)
        registry
          .modules[symbol.module_name]
          &.env
          &.bindings
          &.[](symbol.qualified_name)
          &.then { it.is_a?(Frontend::TypeChecking::Scheme) ? it : nil }
      end

      def render_signature(name, type, constraints)
        "#{name} : #{constraint_prefix(constraints)}#{type}"
      end

      def constraint_prefix(constraints)
        return '' if constraints.empty?

        constraints
          .map { short_constraint(it) }
          .uniq
          .join(', ')
          .then { "#{it} => " }
      end

      def short_constraint(constraint)
        "#{constraint.interface.split('.').last} #{constraint.type}"
      end

      # First node in the path (innermost-to-outermost) that resolves to a
      # symbol. Stops at the most specific resolvable node so a stdlib
      # call doesn't fall through to its enclosing function declaration.
      def innermost_resolved(path, registry, entry)
        path
          .reverse
          .filter_map { resolve_symbol(it, registry, entry) }
          .first
      end

      def resolve_symbol(node, registry, entry)
        case node
        in AST::VariableReference | AST::ConstructorReference |
           AST::QualifiedAccess | AST::FunctionDeclaration |
           AST::TypeDeclaration | AST::StructDeclaration |
           AST::InterfaceDeclaration | AST::VariantDeclaration
          node.symbol.then { resolve_ref(it, registry) }

        in AST::TypeName(type:)
          entry.types[type].then { resolve_ref(it, registry) }

        else
          nil
        end
      end

      def resolve_ref(symbol, registry)
        case symbol
        in Jade::Symbol::ValueRef | Jade::Symbol::TypeRef
          registry.lookup(symbol)
        else
          symbol
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

      def variant_symbol(variant, source)
        document_symbol(variant.name, :enum_member, source, variant.range)
      end

      def interface_fn_symbol(fn, source)
        document_symbol(fn.name, :function, source, fn.range)
      end

      def diagnostic_message(diagnostic)
        [
          diagnostic.message,
          *diagnostic.annotations.map { "#{it.kind}: #{it.message}" },
        ].join("\n")
      end
    end
  end
end

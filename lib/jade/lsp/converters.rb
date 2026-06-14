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
          .then { definition_location(it, registry, entry, source_root) }
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

      # InlayHintKind: 1 = Type, 2 = Parameter
      INLAY_HINT_TYPE = 1
      INLAY_HINT_PARAMETER = 2

      def inlay_hints_for(entry, range_offsets)
        return [] unless entry.env

        collect_inlay_hints(entry.ast, entry, range_offsets)
      end

      # Re-runs the parse + format pipeline on the buffer text. Returns
      # nil if parsing fails (don't overwrite the user's broken buffer
      # with garbage), an empty array if the text is already formatted,
      # or a single whole-document TextEdit otherwise.
      def format_edits(text)
        source = Jade::Source.new(uri: 'buffer', text:)

        case Jade::Parsing.parse(Jade::Lexer.tokenize(source), source:)
        in Jade::Ok([ast, comments])
          formatted = Jade::Formatter.format(ast, comments:, source:) + "\n"
          formatted == text ? [] : [whole_document_edit(source, formatted)]
        in Jade::Err
          nil
        end
      end

      def whole_document_edit(source, new_text)
        last_line = source.line_starts.size - 1
        {
          range: {
            start: { line: 0, character: 0 },
            end:   { line: last_line, character: source.text.bytesize - source.line_starts[last_line] },
          },
          newText: new_text,
        }
      end

      def references_for_path(
        path, registry, entry, source_root, include_declaration:
      )
        symbol = innermost_resolved(path, registry, entry)
        return nil unless symbol

        refs = usage_locations(symbol, registry, source_root)
        return refs unless include_declaration

        refs + declaration_locations(symbol, registry, entry, source_root)
      end

      def prepare_rename_for_path(path, registry, entry, offset)
        node = innermost_resolvable_node(path, registry, entry)
        return nil unless node

        symbol = resolve_symbol(node, registry, entry)
        return nil unless renameable?(symbol, registry)

        identifier_span(node, symbol, entry.source)
          .then { it.cover?(offset) ? span_to_range(entry.source, it) : nil }
      end

      def rename_for_path(path, registry, entry, source_root, new_name)
        symbol = innermost_resolved(path, registry, entry)
        return nil unless renameable?(symbol, registry)

        rename_edits(symbol, registry, entry, source_root)
          .group_by { it[:uri] }
          .transform_values { it.map { |e| { range: e[:range], newText: new_name } } }
          .then { { changes: it } }
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

      def definition_location(symbol, registry, entry, source_root)
        return nil unless symbol&.respond_to?(:decl_span) && symbol.decl_span

        # Locals (Symbol::Variable) carry no module — they're declared in
        # the file the cursor is in, so resolve against the current entry.
        source =
          if symbol.respond_to?(:module_name)
            registry.modules.fetch(symbol.module_name).source
          else
            entry.source
          end

        source && build_location(source, symbol.decl_span, source_root)
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

      def declaration_locations(symbol, registry, entry, source_root)
        definition_location(symbol, registry, entry, source_root)
          .then { it ? [it] : [] }
      end

      # Rename targets must have a declaration we can point at AND live
      # in a module whose source we can write back. Stdlib and interop
      # modules are excluded for both reasons. Locals (Symbol::Variable)
      # carry no module — they live in the file the cursor is in.
      def renameable?(symbol, registry)
        return false unless symbol&.respond_to?(:decl_span) && symbol.decl_span
        return true if symbol.is_a?(Jade::Symbol::Variable)

        registry
          .modules[symbol.module_name]
          .then { it && it.source && !Stdlib.is_stdlib?(it) }
      end

      def rename_edits(symbol, registry, entry, source_root)
        [decl_edit(symbol, registry, entry, source_root)] +
          usage_edits(symbol, registry, source_root)
      end

      def decl_edit(symbol, registry, entry, source_root)
        decl_source(symbol, registry, entry)
          .then { build_location(it, narrowed_decl_span(it, symbol), source_root) }
      end

      # Locals (Variable) belong to the file the cursor is in; module
      # symbols belong to their declaring module.
      def decl_source(symbol, registry, entry)
        symbol.is_a?(Jade::Symbol::Variable) ?
          entry.source :
          registry.modules.fetch(symbol.module_name).source
      end

      # Function/Variable decl_spans are already name-only; Union /
      # Struct / Variant / Interface decl_spans cover the entire
      # declaration. Search the source slice for the identifier so the
      # rename edit replaces just the name in both cases.
      def narrowed_decl_span(source, symbol)
        span = symbol.decl_span
        offset = source.text.byteslice(span.begin, span.size)&.index(symbol.name)
        return span unless offset

        (span.begin + offset)...(span.begin + offset + symbol.name.bytesize)
      end

      # Reference ranges from usage_index cover the whole node (e.g.
      # `M.foo` for QualifiedAccess), so we trim to the trailing
      # identifier. For bare VariableReference / ConstructorReference
      # the range already equals the identifier — trimming is a no-op.
      def usage_edits(symbol, registry, source_root)
        registry
          .modules
          .each_value
          .flat_map do |entry|
            next [] unless entry.source && entry.usage_index

            entry
              .usage_index
              .for(symbol)
              .map { trail_identifier_span(it.range, symbol.name) }
              .map { build_location(entry.source, it, source_root) }
          end
      end

      def trail_identifier_span(range, name)
        (range.end - name.bytesize)...range.end
      end

      # Walks the AST gathering inlay hints. Every Pattern::Binding
      # with a pinned type produces a hint — naturally covers let-
      # bindings (`x = expr`), case-of pattern bindings (`in Just(x)`),
      # and lambda params (`(x) -> ...`) once their types are pinned.
      def collect_inlay_hints(node, entry, range_offsets)
        return [] unless node.is_a?(AST::Node)

        own = node.is_a?(AST::Pattern::Binding) ?
          binding_hint(node, entry, range_offsets) : nil

        children_of(node)
          .flat_map { collect_inlay_hints(it, entry, range_offsets) }
          .then { own ? [own] + it : it }
      end

      def children_of(node)
        (node.members - AST::Node::BOILERPLATE_FIELDS)
          .flat_map { node.public_send(it) }
          .flat_map { it.is_a?(Array) ? it : [it] }
      end

      def binding_hint(binding, entry, range_offsets)
        return nil unless range_offsets.cover?(binding.range.end)

        type = entry.env.node_types[binding.id]
        return nil unless type

        {
          position: offset_to_position(entry.source, binding.range.end),
          label: ": #{type}",
          kind: INLAY_HINT_TYPE,
          paddingLeft: false,
          paddingRight: false,
        }
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
        innermost_resolvable_node(path, registry, entry)
          &.then { resolve_symbol(it, registry, entry) }
      end

      def innermost_resolvable_node(path, registry, entry)
        path.reverse.find { resolve_symbol(it, registry, entry) }
      end

      # For prepareRename / rename — identifier-only span of `node`.
      # QualifiedAccess ranges include the `Module.` prefix, so trim
      # to the trailing identifier. Declaration nodes fall back to
      # narrowing `symbol.decl_span` (which is the whole declaration
      # for Union / Struct / Variant / Interface, name-only for
      # Function / Variable).
      def identifier_span(node, symbol, source)
        case node
        in AST::QualifiedAccess
          trail_identifier_span(node.range, symbol.name)
        in AST::VariableReference | AST::ConstructorReference |
           AST::ExposeValue | AST::ExposeType | AST::ExposeTypeExpand
          node.range
        else
          narrowed_decl_span(source, symbol)
        end
      end

      def resolve_symbol(node, registry, entry)
        case node
        in AST::VariableReference | AST::ConstructorReference |
           AST::QualifiedAccess | AST::FunctionDeclaration |
           AST::TypeDeclaration | AST::StructDeclaration |
           AST::InterfaceDeclaration | AST::VariantDeclaration
          node.symbol.then { resolve_ref(it, registry) }

        in AST::FunctionDeclarationParam(name:, range:)
          Jade::Symbol::Variable.new(name:, decl_span: range)

        in AST::TypeName(type:)
          entry.types[type].then { resolve_ref(it, registry) }

        in AST::ExposeValue(name:)
          entry.lookup_value(name)&.then { resolve_ref(it, registry) }

        in AST::ExposeType | AST::ExposeTypeExpand
          entry.lookup_type(node.name)&.then { resolve_ref(it, registry) }

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

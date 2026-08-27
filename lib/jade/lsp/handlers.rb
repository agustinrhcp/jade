require 'pathname'

module Jade
  module LSP
    module Handlers
      extend self

      def dispatch(state, message)
        case message['method']
        when 'initialize' then on_initialize(state, message)
        when 'initialized' then [state, []]
        when 'shutdown' then [state, [respond(message['id'], nil)]]
        when 'exit' then [state, []]
        when 'textDocument/didOpen' then on_did_open(state, message['params'])
        when 'textDocument/didChange' then on_did_change(state, message['params'])
        when 'textDocument/didSave' then [state, []]
        when 'textDocument/didClose' then on_did_close(state, message['params'])
        when 'textDocument/documentSymbol' then on_document_symbol(state, message)
        when 'textDocument/hover' then on_hover(state, message)
        when 'textDocument/definition' then on_definition(state, message)
        when 'textDocument/references' then on_references(state, message)
        when 'textDocument/completion' then on_completion(state, message)
        when 'textDocument/prepareRename' then on_prepare_rename(state, message)
        when 'textDocument/rename' then on_rename(state, message)
        when 'textDocument/inlayHint' then on_inlay_hint(state, message)
        when 'textDocument/formatting' then on_formatting(state, message)
        else on_unknown(state, message)
        end
      end

      private

      def on_unknown(state, message)
        return [state, []] unless message['id']

        error = respond_error(message['id'], -32601, "method not found: #{message['method']}")
        [state, [error]]
      end

      def on_initialize(state, message)
        params = (message['params'] || {})
        # The editor's root is the project root, not the source root the
        # compiler names modules from. Reading the manifest also loads the
        # extension gems a project imports.
        project = params
          .then { it['rootUri'] || it.dig('workspaceFolders', 0, 'uri') }
          .then { it ? it.sub(%r{\Afile://}, '') : Dir.pwd }
          .then { [Project.find(it), it] }

        {
          capabilities: {
            textDocumentSync: { openClose: true, change: 1 },
            positionEncoding: negotiate_encoding(params),
            documentSymbolProvider: true,
            hoverProvider: true,
            definitionProvider: true,
            referencesProvider: true,
            completionProvider: { resolveProvider: false },
            renameProvider: { prepareProvider: true },
            inlayHintProvider: true,
            documentFormattingProvider: true,
          },
          serverInfo: { name: 'jade-lsp', version: '0.1.0' },
        }
          .then { [state.with_project(*project), [respond(message['id'], it)]] }
      end

      def negotiate_encoding(params)
        params
          .dig('capabilities', 'general', 'positionEncodings')
          &.include?('utf-8') ? 'utf-8' : 'utf-16'
      end

      def on_did_open(state, params)
        params['textDocument']
          .then { state.put_buffer(it['uri'], it['text']) }
          .then { recompile_and_publish(it, scope: :project) }
      end

      def on_did_change(state, params)
        doc = params['textDocument']
        latest = params['contentChanges'].last
        state
          .put_buffer(doc['uri'], latest['text'])
          .then { recompile_and_publish(it) }
      end

      def on_did_close(state, params)
        params['textDocument']['uri']
          .then { recompile_and_publish(state.close(it), extra_uris: [it], scope: :project) }
      end

      def on_document_symbol(state, message)
        symbols = message
          .dig('params', 'textDocument', 'uri')
          .then { document_symbols_for(state, it) }
        [state, [respond(message['id'], symbols)]]
      end

      def on_hover(state, message)
        message['params']
          .then { hover_for(state, it['textDocument']['uri'], it['position']) }
          .then { [state, [respond(message['id'], it)]] }
      end

      def on_definition(state, message)
        message['params']
          .then { definition_for(state, it['textDocument']['uri'], it['position']) }
          .then { [state, [respond(message['id'], it)]] }
      end

      def on_references(state, message)
        params = message['params']
        references_for(
          state,
          params['textDocument']['uri'],
          params['position'],
          include_declaration: params.dig('context', 'includeDeclaration'),
        ).then { [state, [respond(message['id'], it)]] }
      end

      def on_completion(state, message)
        message
          .dig('params', 'textDocument', 'uri')
          .then { module_name_for(it, state.source_root) }
          .then { [state, [respond(message['id'], Converters.completion_items(it))]] }
      end

      def module_name_for(uri, source_root)
        return nil unless uri && source_root

        Converters
          .relative_path(uri, source_root)
          .then { Source.module_name_for(it) }
      end

      def on_prepare_rename(state, message)
        message['params']
          .then { prepare_rename_for(state, it['textDocument']['uri'], it['position']) }
          .then { [state, [respond(message['id'], it)]] }
      end

      def on_rename(state, message)
        params = message['params']
        rename_for(
          state,
          params['textDocument']['uri'],
          params['position'],
          params['newName'],
        ).then { [state, [respond(message['id'], it)]] }
      end

      def on_inlay_hint(state, message)
        params = message['params']
        inlay_hints_for(
          state, params['textDocument']['uri'], params['range'],
        ).then { [state, [respond(message['id'], it)]] }
      end

      def on_formatting(state, message)
        uri = message.dig('params', 'textDocument', 'uri')
        edits = formatting_edits_for(state, uri)
        [state, [respond(message['id'], edits)]]
      end

      def formatting_edits_for(state, uri)
        text = state.buffers[uri]
        return nil unless text

        Converters.format_edits(text)
      end

      def inlay_hints_for(state, uri, lsp_range)
        return [] unless state.registry

        rel = Converters.relative_path(uri, state.source_root)
        entry = state.registry.modules.each_value.find { it.source&.uri == rel }
        return [] unless entry

        start_offset = Converters.position_to_offset(
          entry.source, lsp_range['start']['line'], lsp_range['start']['character'],
        )
        end_offset = Converters.position_to_offset(
          entry.source, lsp_range['end']['line'], lsp_range['end']['character'],
        )

        Converters.inlay_hints_for(entry, start_offset..end_offset)
      end

      def prepare_rename_for(state, uri, position)
        return nil unless state.registry

        rel = Converters.relative_path(uri, state.source_root)
        entry = state.registry.modules.each_value.find { it.source&.uri == rel }
        return nil unless entry

        offset = Converters.position_to_offset(
          entry.source, position['line'], position['character']
        )
        Converters.prepare_rename_for_path(
          entry.ast.find_at_path(offset), state.registry, entry, offset,
        )
      end

      def rename_for(state, uri, position, new_name)
        return nil unless state.registry

        rel = Converters.relative_path(uri, state.source_root)
        entry = state.registry.modules.each_value.find { it.source&.uri == rel }
        return nil unless entry

        Converters
          .position_to_offset(entry.source, position['line'], position['character'])
          .then { entry.ast.find_at_path(it) }
          .then do |path|
            Converters.rename_for_path(
              path, state.registry, entry, state.source_root, new_name,
            )
          end
      end

      def references_for(state, uri, position, include_declaration:)
        return nil unless state.registry

        rel = Converters.relative_path(uri, state.source_root)
        entry = state.registry.modules.each_value.find { it.source&.uri == rel }
        return nil unless entry

        Converters
          .position_to_offset(entry.source, position['line'], position['character'])
          .then { entry.ast.find_at_path(it) }
          .then do |path|
            Converters.references_for_path(
              path, state.registry, entry, state.source_root,
              include_declaration:,
            )
          end
      end

      def definition_for(state, uri, position)
        return nil unless state.registry

        rel = Converters.relative_path(uri, state.source_root)
        entry = state.registry.modules.each_value.find { it.source&.uri == rel }
        return nil unless entry

        Converters
          .position_to_offset(entry.source, position['line'], position['character'])
          .then { entry.ast.find_at_path(it) }
          .then { Converters.definition_for_path(it, state.registry, entry, state.source_root) }
      end

      def hover_for(state, uri, position)
        return nil unless state.registry

        rel = Converters.relative_path(uri, state.source_root)
        entry = state.registry.modules.each_value.find { it.source&.uri == rel }
        return nil unless entry

        Converters
          .position_to_offset(entry.source, position['line'], position['character'])
          .then { Converters.hover_for_path(entry.ast.find_at_path(it), state.registry, entry) }
      end

      def document_symbols_for(state, uri)
        return [] unless state.registry

        rel = Converters.relative_path(uri, state.source_root)
        entry = state.registry.modules.each_value.find { it.source&.uri == rel }
        return [] unless entry

        entry.ast.body.expressions
          .filter_map { Converters.to_document_symbol(it, entry.source) }
      end

      # extra_uris always receive a publishDiagnostics, but compile output
      # wins: if a real diagnostic came back for the URI, we send that, not
      # an empty clear.
      def recompile_and_publish(state, extra_uris: [], scope: :buffers)
        return [state, extra_uris.map { publish_for(it, []) }] if state.source_root.nil?

        overlays = state.buffers
          .to_h { |uri, text| [Converters.relative_path(uri, state.source_root), text] }

        diagnostics_by_uri, registry =
          compile_each(state, overlays, entries(state, overlays, scope))

        uris = (diagnostics_by_uri.keys + state.buffers.keys + state.published + extra_uris).uniq
        messages = uris.map { publish_for(it, diagnostics_by_uri[it] || []) }

        next_state = (registry ? state.set_registry(registry) : state)
          .with_published(diagnostics_by_uri.keys)
        [next_state, messages]
      end

      # Typing recompiles what is open; opening and closing sweep.
      def entries(state, overlays, scope)
        return overlays.keys if scope == :buffers

        Dir
          .glob('**/*.jd', base: state.source_root)
          .sort
          .then { imported_last(it, state.registry) }
      end

      # Compiling a module compiles what it imports, so the modules nothing
      # imports cover the project in one pass. A file the last compile never
      # saw goes first, since it may be the new root.
      def imported_last(paths, registry)
        return paths unless registry

        [imported(registry), module_names(registry)]
          .then { |names, by_path| paths.partition { !names.include?(by_path[it]) } }
          .flatten
      end

      def imported(registry)
        registry.dependency_graph.nodes.values.flatten.to_set
      end

      def module_names(registry)
        registry
          .modules
          .each_value
          .filter_map { [it.source.uri, it.name] if it.source }
          .to_h
      end

      def compile_each(state, overlays, entries)
        entries
          .reduce([{}, nil, []]) { |acc, entry| compile_unless_seen(acc, state, overlays, entry) }
          .first(2)
      end

      def compile_unless_seen((diagnostics, registry, seen), state, overlays, entry)
        return [diagnostics, registry, seen] if seen.include?(entry)

        compile(state, entry, overlays)
          .then { |(compiled, found)| [diagnostics.merge(found), compiled || registry, seen + compiled_paths(compiled)] }
      end

      def compiled_paths(registry)
        return [] unless registry

        registry
          .modules
          .each_value
          .reject { Stdlib.is_stdlib?(it) }
          .filter_map { it.source&.uri }
      end

      def compile(state, entry_path, overlays)
        ModuleLoader
          .load(state.source_root, entry_path, cache_dir: state.cache_dir, tolerant: true, overlays:)
          .then { [it, collect_diagnostics(it, state.source_root)] }
      rescue Jade::CompilationError => e
        [nil, diagnostics_by_uri(e.diagnostics, state.source_root)]
      rescue StandardError => e
        $stderr.puts "[jade-lsp] compile crash: #{e.class}: #{e.message}"
        $stderr.puts e.backtrace.first(20).join("\n")
        [nil, crash_diagnostic(state.source_root, entry_path, overlays, e)]
      end

      # Publishing nothing renders a crashed compile as a clean file.
      def crash_diagnostic(source_root, entry_path, overlays, error)
        Jade::Source
          .new(uri: entry_path, text: overlays[entry_path] || '')
          .then { Jade::Diagnostics::Label[it, 0...0, nil] }
          .then do
            Jade::Diagnostics::Diagnostic.error(
              "jade-lsp crashed compiling this file: #{error.class}: #{error.message}",
              primary: it,
            )
          end
          .then { { Converters.lsp_uri(entry_path, source_root) => [it] } }
      end

      def collect_diagnostics(registry, source_root)
        registry
          .modules
          .each_value
          .reject { Stdlib.is_stdlib?(it) }
          .reject { it.source.nil? || it.diagnostics.items.empty? }
          .reduce({}) do |acc, entry|
            acc.merge(Converters.lsp_uri(entry.source.uri, source_root) => entry.diagnostics.items)
          end
      end

      def diagnostics_by_uri(list, source_root)
        list.items
          .group_by { it.primary.source.uri }
          .transform_keys { Converters.lsp_uri(it, source_root) }
      end

      def publish_for(uri, items)
        notify('textDocument/publishDiagnostics', {
          uri:,
          diagnostics: items.map { Converters.diagnostic_to_lsp(it) },
        })
      end

      def respond(id, result)
        { jsonrpc: '2.0', id:, result: }
      end

      def respond_error(id, code, message)
        { jsonrpc: '2.0', id:, error: { code:, message: } }
      end

      def notify(method, params)
        { jsonrpc: '2.0', method:, params: }
      end
    end
  end
end

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
        root = params
          .then { it['rootUri'] || it.dig('workspaceFolders', 0, 'uri') }
          .then { it ? it.sub(%r{\Afile://}, '') : Dir.pwd }

        {
          capabilities: {
            textDocumentSync: { openClose: true, change: 1 },
            positionEncoding: negotiate_encoding(params),
            documentSymbolProvider: true,
          },
          serverInfo: { name: 'jade-lsp', version: '0.1.0' },
        }
          .then { [state.with_root(root), [respond(message['id'], it)]] }
        
      end

      def negotiate_encoding(params)
        params
          .dig('capabilities', 'general', 'positionEncodings')
          &.include?('utf-8') ? 'utf-8' : 'utf-16'
      end

      def on_did_open(state, params)
        params['textDocument']
          .then { state.put_buffer(it['uri'], it['text']) }
          .then { recompile_and_publish(it) }
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
          .then { recompile_and_publish(state.close(it), extra_uris: [it]) }
      end

      def on_document_symbol(state, message)
        symbols = message
          .dig('params', 'textDocument', 'uri')
          .then { document_symbols_for(state, it) }
        [state, [respond(message['id'], symbols)]]
      end

      def document_symbols_for(state, uri)
        return [] unless state.registry && state.source_root

        rel = Converters.relative_path(uri, state.source_root)
        entry = state.registry.modules.each_value.find { it.source&.uri == rel }
        return [] unless entry

        entry.ast.body.expressions
          .filter_map { Converters.to_document_symbol(it, entry.source) }
      end

      # extra_uris always receive a publishDiagnostics, but compile output
      # wins: if a real diagnostic came back for the URI, we send that, not
      # an empty clear.
      def recompile_and_publish(state, extra_uris: [])
        if state.buffers.empty? || state.source_root.nil?
          return [state, extra_uris.map { publish_for(it, []) }]
        end

        overlays = state.buffers
          .to_h { |uri, text| [Converters.relative_path(uri, state.source_root), text] }

        diagnostics_by_uri, registry = compile_each(state.source_root, overlays)

        uris = (diagnostics_by_uri.keys + state.buffers.keys + extra_uris).uniq
        messages = uris.map { publish_for(it, diagnostics_by_uri[it] || []) }

        next_state = registry ? state.set_registry(registry) : state
        [next_state, messages]
      end

      # Compile from each open buffer so unrelated modules still produce
      # diagnostics. The same module reached twice yields identical
      # diagnostics (deterministic over overlays), so Hash#merge is safe.
      def compile_each(source_root, overlays)
        overlays.keys.reduce([{}, nil]) do |(diag_acc, reg_acc), entry|
          registry, diagnostics = compile(source_root, entry, overlays)
          [diag_acc.merge(diagnostics), registry || reg_acc]
        end
      end

      def compile(source_root, entry_path, overlays)
        ModuleLoader
          .load(source_root, entry_path, tolerant: true, overlays:)
          .then { [it, collect_diagnostics(it, source_root)] }
      rescue Jade::CompilationError => e
        [nil, diagnostics_by_uri(e.diagnostics, source_root)]
      rescue StandardError => e
        $stderr.puts "[jade-lsp] compile crash: #{e.class}: #{e.message}"
        $stderr.puts e.backtrace.first(20).join("\n")
        [nil, {}]
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

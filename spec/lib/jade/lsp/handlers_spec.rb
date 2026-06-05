require 'spec_helper'
require 'tmpdir'
require 'fileutils'

require 'jade/lsp'

module Jade
  module LSP
    describe Handlers do
      let(:project) { Dir.mktmpdir('jade-lsp-spec') }
      let(:src)     { File.join(project, 'src') }
      let(:uri)     { "file://#{src}/leaf.jd" }

      let(:leaf) do
        <<~JADE
          module Leaf exposing (n)

          def n -> Int
            42
          end
        JADE
      end

      before { FileUtils.mkdir_p(src) }
      after  { FileUtils.rm_rf(project) }

      def initialized_state
        Handlers.dispatch(State.empty, {
          'method' => 'initialize',
          'id' => 1,
          'params' => { 'rootUri' => "file://#{src}" },
        }).first
      end

      describe 'initialize' do
        subject { Handlers.dispatch(State.empty, message) }

        let(:message) do
          { 'method' => 'initialize', 'id' => 1, 'params' => { 'rootUri' => "file://#{src}" } }
        end

        it 'records the source root' do
          state, _ = subject
          expect(state.source_root).to eq src
        end

        it 'responds with capabilities' do
          _, outbound = subject
          expect(outbound.size).to eq 1
          response = outbound.first
          expect(response[:id]).to eq 1
          expect(response[:result][:capabilities][:textDocumentSync]).to include(openClose: true, change: 1)
        end

        it 'advertises documentSymbolProvider' do
          _, outbound = subject
          expect(outbound.first[:result][:capabilities][:documentSymbolProvider]).to eq true
        end

        it 'advertises hoverProvider' do
          _, outbound = subject
          expect(outbound.first[:result][:capabilities][:hoverProvider]).to eq true
        end

        it 'advertises definitionProvider' do
          _, outbound = subject
          expect(outbound.first[:result][:capabilities][:definitionProvider]).to eq true
        end

        it 'advertises completionProvider' do
          _, outbound = subject
          provider = outbound.first[:result][:capabilities][:completionProvider]
          expect(provider).to include(resolveProvider: false)
        end

        it 'advertises renameProvider with prepareRename' do
          _, outbound = subject
          provider = outbound.first[:result][:capabilities][:renameProvider]
          expect(provider).to include(prepareProvider: true)
        end

        it 'advertises inlayHintProvider' do
          _, outbound = subject
          expect(outbound.first[:result][:capabilities][:inlayHintProvider]).to eq true
        end

        it 'advertises documentFormattingProvider' do
          _, outbound = subject
          expect(outbound.first[:result][:capabilities][:documentFormattingProvider]).to eq true
        end

        it 'advertises utf-8 when the client supports it' do
          _, outbound = Handlers.dispatch(State.empty, {
            'method' => 'initialize',
            'id' => 1,
            'params' => {
              'rootUri' => "file://#{src}",
              'capabilities' => { 'general' => { 'positionEncodings' => ['utf-16', 'utf-8'] } },
            },
          })
          expect(outbound.first[:result][:capabilities][:positionEncoding]).to eq 'utf-8'
        end

        it 'falls back to utf-16 when the client does not advertise utf-8' do
          _, outbound = subject
          expect(outbound.first[:result][:capabilities][:positionEncoding]).to eq 'utf-16'
        end
      end

      describe 'didOpen on a clean file' do
        subject do
          File.write(File.join(src, 'leaf.jd'), leaf)
          Handlers.dispatch(initialized_state, {
            'method' => 'textDocument/didOpen',
            'params' => { 'textDocument' => { 'uri' => uri, 'text' => leaf } },
          })
        end

        it 'publishes empty diagnostics for the open buffer' do
          _, outbound = subject
          publish = outbound.find { it[:method] == 'textDocument/publishDiagnostics' }
          expect(publish[:params][:uri]).to eq uri
          expect(publish[:params][:diagnostics]).to be_empty
        end

        it 'stashes the buffer on state' do
          state, _ = subject
          expect(state.buffers[uri]).to include('42')
        end
      end

      describe 'didOpen with an in-buffer syntax error (disk is clean)' do
        let(:broken) { leaf + "garbage\n" }

        subject do
          File.write(File.join(src, 'leaf.jd'), leaf)
          Handlers.dispatch(initialized_state, {
            'method' => 'textDocument/didOpen',
            'params' => { 'textDocument' => { 'uri' => uri, 'text' => broken } },
          })
        end

        it 'publishes a diagnostic with severity error' do
          _, outbound = subject
          diags = outbound.find { it[:method] == 'textDocument/publishDiagnostics' }[:params][:diagnostics]
          expect(diags).not_to be_empty
          expect(diags.first[:severity]).to eq Converters::SEVERITY[:error]
        end
      end

      describe 'didChange after didOpen' do
        subject do
          File.write(File.join(src, 'leaf.jd'), leaf)
          state, _ = Handlers.dispatch(initialized_state, {
            'method' => 'textDocument/didOpen',
            'params' => { 'textDocument' => { 'uri' => uri, 'text' => leaf } },
          })
          Handlers.dispatch(state, {
            'method' => 'textDocument/didChange',
            'params' => {
              'textDocument' => { 'uri' => uri },
              'contentChanges' => [{ 'text' => leaf.sub('42', '99') }],
            },
          })
        end

        it 'updates the buffer to the new text' do
          state, _ = subject
          expect(state.buffers[uri]).to include('99')
          expect(state.buffers[uri]).not_to include('42')
        end
      end

      describe 'didChange broken -> clean' do
        let(:broken) { leaf + "garbage\n" }

        it 'publishes empty diagnostics to clear stale ones' do
          File.write(File.join(src, 'leaf.jd'), leaf)
          state, _ = Handlers.dispatch(initialized_state, {
            'method' => 'textDocument/didOpen',
            'params' => { 'textDocument' => { 'uri' => uri, 'text' => broken } },
          })
          _, outbound = Handlers.dispatch(state, {
            'method' => 'textDocument/didChange',
            'params' => {
              'textDocument' => { 'uri' => uri },
              'contentChanges' => [{ 'text' => leaf }],
            },
          })

          publish = outbound.find { it[:method] == 'textDocument/publishDiagnostics' }
          expect(publish[:params][:uri]).to eq uri
          expect(publish[:params][:diagnostics]).to be_empty
        end
      end

      describe 'didClose' do
        subject do
          File.write(File.join(src, 'leaf.jd'), leaf)
          state, _ = Handlers.dispatch(initialized_state, {
            'method' => 'textDocument/didOpen',
            'params' => { 'textDocument' => { 'uri' => uri, 'text' => leaf } },
          })
          Handlers.dispatch(state, {
            'method' => 'textDocument/didClose',
            'params' => { 'textDocument' => { 'uri' => uri } },
          })
        end

        it 'drops the buffer' do
          state, _ = subject
          expect(state.buffers).to be_empty
        end

        it 'publishes empty diagnostics for the closed URI' do
          _, outbound = subject
          publish = outbound.find { it[:method] == 'textDocument/publishDiagnostics' && it[:params][:uri] == uri }
          expect(publish).not_to be_nil
          expect(publish[:params][:diagnostics]).to be_empty
        end
      end

      describe 'multi-buffer' do
        let(:other_uri) { "file://#{src}/other.jd" }
        let(:other) do
          <<~JADE
            module Other exposing (m)

            def m -> Int
              "boom"
            end
          JADE
        end

        it 'publishes diagnostics for each open buffer independently' do
          File.write(File.join(src, 'leaf.jd'), leaf)
          File.write(File.join(src, 'other.jd'), other)
          state, _ = Handlers.dispatch(initialized_state, {
            'method' => 'textDocument/didOpen',
            'params' => { 'textDocument' => { 'uri' => uri, 'text' => leaf } },
          })
          _, outbound = Handlers.dispatch(state, {
            'method' => 'textDocument/didOpen',
            'params' => { 'textDocument' => { 'uri' => other_uri, 'text' => other } },
          })

          publishes = outbound.select { it[:method] == 'textDocument/publishDiagnostics' }
          by_uri = publishes.to_h { |m| [m[:params][:uri], m[:params][:diagnostics]] }
          expect(by_uri[uri]).to be_empty
          expect(by_uri[other_uri]).not_to be_empty
        end
      end

      describe 'documentSymbol' do
        let(:module_text) do
          <<~JADE
            module Leaf exposing (Color, n)

            type Color
              = Red
              | Green
              | Blue


            def n -> Int
              42
            end
          JADE
        end

        def open_and_request_symbols(text:)
          File.write(File.join(src, 'leaf.jd'), text)
          state, _ = Handlers.dispatch(initialized_state, {
            'method' => 'textDocument/didOpen',
            'params' => { 'textDocument' => { 'uri' => uri, 'text' => text } },
          })
          Handlers.dispatch(state, {
            'method' => 'textDocument/documentSymbol',
            'id' => 99,
            'params' => { 'textDocument' => { 'uri' => uri } },
          })
        end

        it 'returns a function symbol for a top-level def' do
          _, outbound = open_and_request_symbols(text: module_text)
          symbols = outbound.first[:result]
          fn = symbols.find { it[:name] == 'n' }
          expect(fn[:kind]).to eq Converters::SYMBOL_KIND[:function]
        end

        it 'returns a type symbol with its variants as children' do
          _, outbound = open_and_request_symbols(text: module_text)
          symbols = outbound.first[:result]
          type = symbols.find { it[:name] == 'Color' }
          expect(type[:kind]).to eq Converters::SYMBOL_KIND[:enum]
          expect(type[:children].map { it[:name] }).to contain_exactly('Red', 'Green', 'Blue')
          expect(type[:children].first[:kind]).to eq Converters::SYMBOL_KIND[:enum_member]
        end

        it 'returns an empty list for a uri that is not in the registry' do
          state, _ = Handlers.dispatch(initialized_state, {
            'method' => 'textDocument/didOpen',
            'params' => { 'textDocument' => { 'uri' => uri, 'text' => module_text } },
          })
          _, outbound = Handlers.dispatch(state, {
            'method' => 'textDocument/documentSymbol',
            'id' => 1,
            'params' => { 'textDocument' => { 'uri' => "file://#{src}/missing.jd" } },
          })
          expect(outbound.first[:result]).to eq []
        end

        it 'returns an empty list when no compile has run' do
          _, outbound = Handlers.dispatch(initialized_state, {
            'method' => 'textDocument/documentSymbol',
            'id' => 1,
            'params' => { 'textDocument' => { 'uri' => uri } },
          })
          expect(outbound.first[:result]).to eq []
        end
      end

      describe 'hover' do
        let(:hover_text) do
          <<~JADE
            module Leaf exposing (n)

            def helper(x: Int) -> Int
              x + 1
            end


            def n -> Int
              helper(42)
            end
          JADE
        end

        def open_and_hover(text:, at:)
          File.write(File.join(src, 'leaf.jd'), text)
          state, _ = Handlers.dispatch(initialized_state, {
            'method' => 'textDocument/didOpen',
            'params' => { 'textDocument' => { 'uri' => uri, 'text' => text } },
          })
          offset = text.index(at)
          line = text[0...offset].count("\n")
          character = offset - (text.rindex("\n", offset) || -1) - 1
          Handlers.dispatch(state, {
            'method' => 'textDocument/hover',
            'id' => 42,
            'params' => {
              'textDocument' => { 'uri' => uri },
              'position' => { 'line' => line, 'character' => character },
            },
          })
        end

        it 'returns a signature for a module-level function reference' do
          _, outbound = open_and_hover(text: hover_text, at: 'helper(42)')
          result = outbound.first[:result]
          expect(result[:contents][:value]).to include('helper')
          expect(result[:contents][:value]).to include('Int')
          expect(result[:contents][:kind]).to eq 'markdown'
        end

        it 'returns nil when the cursor is not on a hoverable node' do
          _, outbound = open_and_hover(text: hover_text, at: 'module Leaf')
          expect(outbound.first[:result]).to be_nil
        end

        it 'returns the enclosing function signature when hovering inside its body whitespace' do
          _, outbound = open_and_hover(text: hover_text, at: '  x + 1')
          expect(outbound.first[:result][:contents][:value]).to include('helper')
        end

        it 'renders inferred constraints for constrained function calls' do
          text = <<~JADE
            module M exposing (caller)

            def eq_check(a: a, b: a) -> Bool
              a == b
            end


            def caller(x: Int) -> Bool
              eq_check(x, x)
            end
          JADE
          _, outbound = open_and_hover(text:, at: 'eq_check(x, x)')
          expect(outbound.first[:result][:contents][:value]).to include('Eq a => ')
        end

        it 'lists implemented interfaces under a type hover' do
          text = <<~JADE
            module M exposing (Box, run)

            type Box = Box(Int)


            implements Chainable(Box) with
              and_then: and_then_box
            end


            def and_then_box(m: Box, f: Box -> Box) -> Box
              f(m)
            end


            def run(b: Box) -> Box
              b
            end
          JADE
          _, outbound = open_and_hover(text:, at: 'Box) -> Box')
          val = outbound.first[:result][:contents][:value]
          expect(val).to include('type Box')
          expect(val).to include('implements Chainable')
        end

        describe 'pinned-type fallback' do
          let(:locals_text) do
            <<~JADE
              module M exposing (run)

              def run(x: Int) -> Int
                doubled = x * 2
                doubled + 1
              end
            JADE
          end

          it 'renders a local let-binding with its name and inferred type' do
            _, outbound = open_and_hover(text: locals_text, at: 'doubled = ')
            expect(outbound.first[:result][:contents][:value]).to include('doubled : Int')
          end

          it 'renders an intermediate expression as just its type' do
            _, outbound = open_and_hover(text: locals_text, at: 'x * 2')
            expect(outbound.first[:result][:contents][:value]).to include('Int')
          end
        end

        it 'returns nil before any compile has run' do
          _, outbound = Handlers.dispatch(initialized_state, {
            'method' => 'textDocument/hover',
            'id' => 1,
            'params' => {
              'textDocument' => { 'uri' => uri },
              'position' => { 'line' => 0, 'character' => 0 },
            },
          })
          expect(outbound.first[:result]).to be_nil
        end
      end

      describe 'definition' do
        let(:def_text) do
          <<~JADE
            module Leaf exposing (n)

            def helper(x: Int) -> Int
              x + 1
            end


            def n -> Int
              helper(42)
            end
          JADE
        end

        def open_and_define(text:, at:)
          File.write(File.join(src, 'leaf.jd'), text)
          state, _ = Handlers.dispatch(initialized_state, {
            'method' => 'textDocument/didOpen',
            'params' => { 'textDocument' => { 'uri' => uri, 'text' => text } },
          })
          offset = text.index(at)
          line = text[0...offset].count("\n")
          character = offset - (text.rindex("\n", offset) || -1) - 1
          Handlers.dispatch(state, {
            'method' => 'textDocument/definition',
            'id' => 11,
            'params' => {
              'textDocument' => { 'uri' => uri },
              'position' => { 'line' => line, 'character' => character },
            },
          })
        end

        it 'returns a Location for a local function reference' do
          _, outbound = open_and_define(text: def_text, at: 'helper(42)')
          loc = outbound.first[:result]
          expect(loc[:uri]).to eq uri
          # helper is declared on line 2 (0-indexed)
          expect(loc[:range][:start][:line]).to eq 2
        end

        it 'returns nil for stdlib calls (no decl_span yet)' do
          text = "module Leaf exposing (n)\n\ndef n() -> Int\n  String.length(\"hi\")\nend\n"
          _, outbound = open_and_define(text:, at: 'String.length')
          expect(outbound.first[:result]).to be_nil
        end

        it 'returns nil before any compile has run' do
          _, outbound = Handlers.dispatch(initialized_state, {
            'method' => 'textDocument/definition',
            'id' => 1,
            'params' => {
              'textDocument' => { 'uri' => uri },
              'position' => { 'line' => 0, 'character' => 0 },
            },
          })
          expect(outbound.first[:result]).to be_nil
        end
      end

      describe 'references' do
        let(:text) do
          <<~JADE
            module M exposing (run)

            def helper(x: Int) -> Int
              x + 1
            end

            def run() -> Int
              helper(1) + helper(2)
            end
          JADE
        end

        def open_and_find_refs(at:, include_declaration:)
          File.write(File.join(src, 'leaf.jd'), text)
          state, _ = Handlers.dispatch(initialized_state, {
            'method' => 'textDocument/didOpen',
            'params' => { 'textDocument' => { 'uri' => uri, 'text' => text } },
          })
          offset = text.index(at)
          line = text[0...offset].count("\n")
          character = offset - (text.rindex("\n", offset) || -1) - 1
          Handlers.dispatch(state, {
            'method' => 'textDocument/references',
            'id' => 21,
            'params' => {
              'textDocument' => { 'uri' => uri },
              'position' => { 'line' => line, 'character' => character },
              'context' => { 'includeDeclaration' => include_declaration },
            },
          })
        end

        it 'returns every call site (without declaration by default)' do
          _, outbound = open_and_find_refs(at: 'helper(1)', include_declaration: false)
          expect(outbound.first[:result].size).to eq 2
        end

        it 'includes the declaration when includeDeclaration is true' do
          _, outbound = open_and_find_refs(at: 'helper(1)', include_declaration: true)
          expect(outbound.first[:result].size).to eq 3
        end

        it 'returns nil when cursor is not on a resolvable symbol' do
          _, outbound = open_and_find_refs(at: 'module M', include_declaration: true)
          expect(outbound.first[:result]).to be_nil
        end
      end

      describe 'rename' do
        let(:text) do
          <<~JADE
            module M exposing (run)

            def helper(x: Int) -> Int
              x + 1
            end

            def run() -> Int
              helper(1) + helper(2)
            end
          JADE
        end

        def open_and_dispatch(method:, id:, at:, extra: {})
          File.write(File.join(src, 'leaf.jd'), text)
          state, _ = Handlers.dispatch(initialized_state, {
            'method' => 'textDocument/didOpen',
            'params' => { 'textDocument' => { 'uri' => uri, 'text' => text } },
          })
          offset = text.index(at)
          line = text[0...offset].count("\n")
          character = offset - (text.rindex("\n", offset) || -1) - 1
          Handlers.dispatch(state, {
            'method' => method,
            'id' => id,
            'params' => {
              'textDocument' => { 'uri' => uri },
              'position' => { 'line' => line, 'character' => character },
              **extra,
            },
          })
        end

        describe 'prepareRename' do
          it 'returns the identifier range on a call site' do
            _, outbound = open_and_dispatch(
              method: 'textDocument/prepareRename', id: 41, at: 'helper(1)',
            )
            result = outbound.first[:result]
            expect(result).not_to be_nil
            expect(result[:start][:character]).to be < result[:end][:character]
          end

          it 'returns nil for stdlib calls' do
            stdlib_text = "module Leaf exposing (n)\n\ndef n() -> Int\n  String.length(\"hi\")\nend\n"
            File.write(File.join(src, 'leaf.jd'), stdlib_text)
            state, _ = Handlers.dispatch(initialized_state, {
              'method' => 'textDocument/didOpen',
              'params' => { 'textDocument' => { 'uri' => uri, 'text' => stdlib_text } },
            })
            offset = stdlib_text.index('String.length')
            line = stdlib_text[0...offset].count("\n")
            character = offset - (stdlib_text.rindex("\n", offset) || -1) - 1
            _, outbound = Handlers.dispatch(state, {
              'method' => 'textDocument/prepareRename',
              'id' => 42,
              'params' => {
                'textDocument' => { 'uri' => uri },
                'position' => { 'line' => line, 'character' => character },
              },
            })
            expect(outbound.first[:result]).to be_nil
          end

          it 'returns nil when the cursor is not on a resolvable symbol' do
            _, outbound = open_and_dispatch(
              method: 'textDocument/prepareRename', id: 43, at: 'module M',
            )
            expect(outbound.first[:result]).to be_nil
          end
        end

        describe 'rename' do
          it 'returns a WorkspaceEdit covering decl and all usages' do
            _, outbound = open_and_dispatch(
              method: 'textDocument/rename', id: 51, at: 'helper(1)',
              extra: { 'newName' => 'plus_one' },
            )
            result = outbound.first[:result]
            expect(result[:changes]).to have_key(uri)
            edits = result[:changes][uri]
            expect(edits.size).to eq 3
            expect(edits).to all(include(newText: 'plus_one'))
          end

          it 'returns nil for stdlib calls' do
            stdlib_text = "module Leaf exposing (n)\n\ndef n() -> Int\n  String.length(\"hi\")\nend\n"
            File.write(File.join(src, 'leaf.jd'), stdlib_text)
            state, _ = Handlers.dispatch(initialized_state, {
              'method' => 'textDocument/didOpen',
              'params' => { 'textDocument' => { 'uri' => uri, 'text' => stdlib_text } },
            })
            offset = stdlib_text.index('String.length')
            line = stdlib_text[0...offset].count("\n")
            character = offset - (stdlib_text.rindex("\n", offset) || -1) - 1
            _, outbound = Handlers.dispatch(state, {
              'method' => 'textDocument/rename',
              'id' => 52,
              'params' => {
                'textDocument' => { 'uri' => uri },
                'position' => { 'line' => line, 'character' => character },
                'newName' => 'X',
              },
            })
            expect(outbound.first[:result]).to be_nil
          end
        end

        describe 'coverage' do
          let(:text) do
            <<~JADE
              module M exposing (run, Shape)

              type Shape
                = Circle(Float)

              def run(s: Shape) -> Shape
                s
              end
            JADE
          end

          it 'rename function: includes decl + exposing list entry' do
            _, outbound = open_and_dispatch(
              method: 'textDocument/rename', id: 71, at: 'def run',
              extra: { 'newName' => 'execute' },
            )
            edits = outbound.first[:result][:changes][uri]
            # decl + `exposing (run, ...)` entry = 2 edits
            expect(edits.size).to eq 2
            expect(edits).to all(include(newText: 'execute'))
          end

          it 'rename type: includes decl + exposing entry + type annotations' do
            _, outbound = open_and_dispatch(
              method: 'textDocument/rename', id: 72, at: 'type Shape',
              extra: { 'newName' => 'Geo' },
            )
            edits = outbound.first[:result][:changes][uri]
            # decl + exposing + `s: Shape` + `-> Shape` = 4 edits
            expect(edits.size).to eq 4
            expect(edits).to all(include(newText: 'Geo'))
          end

          it 'rename initiated from the exposing list works' do
            _, outbound = open_and_dispatch(
              method: 'textDocument/rename', id: 74, at: 'run, Shape',
              extra: { 'newName' => 'execute' },
            )
            edits = outbound.first[:result][:changes][uri]
            expect(edits.size).to eq 2
            expect(edits).to all(include(newText: 'execute'))
          end

          it 'rename function param: only edits within the function body + decl' do
            _, outbound = open_and_dispatch(
              method: 'textDocument/rename', id: 73, at: 's: Shape',
              extra: { 'newName' => 'shape' },
            )
            edits = outbound.first[:result][:changes][uri]
            # param decl + 1 body reference = 2 edits
            expect(edits.size).to eq 2
            expect(edits).to all(include(newText: 'shape'))
          end
        end

        describe 'declaration narrowing' do
          let(:text) do
            <<~JADE
              module M exposing (sample)

              type Shape
                = Circle(Float)
                | Square(Float)

              def sample() -> Shape
                Circle(1.0)
              end
            JADE
          end

          def replace_at(text, edit)
            range = edit[:range]
            offset = text.split("\n", -1)[0...range[:start][:line]].sum { it.bytesize + 1 } + range[:start][:character]
            ending = text.split("\n", -1)[0...range[:end][:line]].sum { it.bytesize + 1 } + range[:end][:character]
            text.byteslice(0, offset) + edit[:newText] + text.byteslice(ending..)
          end

          it 'renaming a type touches only the type name (not the whole declaration)' do
            _, outbound = open_and_dispatch(
              method: 'textDocument/rename', id: 61, at: 'type Shape',
              extra: { 'newName' => 'Geo' },
            )
            edits = outbound.first[:result][:changes][uri]
            decl_edit = edits.find { it[:newText] == 'Geo' }
            slice = text.byteslice(
              text.split("\n", -1)[0...decl_edit[:range][:start][:line]].sum { it.bytesize + 1 } + decl_edit[:range][:start][:character],
              'Shape'.bytesize,
            )
            expect(slice).to eq 'Shape'
          end

          it 'renaming a variant declaration only replaces the variant name' do
            _, outbound = open_and_dispatch(
              method: 'textDocument/rename', id: 62, at: 'Circle(Float)',
              extra: { 'newName' => 'Disc' },
            )
            edits = outbound.first[:result][:changes][uri]
            # Two locations: the variant decl, and the call site `Circle(1.0)`.
            expect(edits.size).to eq 2
            edits.each do |e|
              line = text.lines[e[:range][:start][:line]]
              chunk = line.byteslice(
                e[:range][:start][:character], 'Circle'.bytesize
              )
              expect(chunk).to eq 'Circle'
            end
          end
        end
      end

      describe 'inlayHint' do
        let(:text) do
          <<~JADE
            module M exposing (run)

            def run() -> Int
              x = 42
              y = x + 1
              y
            end
          JADE
        end

        let(:hints) do
          File.write(File.join(src, 'leaf.jd'), text)
          state, _ = Handlers.dispatch(initialized_state, {
            'method' => 'textDocument/didOpen',
            'params' => { 'textDocument' => { 'uri' => uri, 'text' => text } },
          })
          last_line = text.lines.size
          _, outbound = Handlers.dispatch(state, {
            'method' => 'textDocument/inlayHint',
            'id' => 81,
            'params' => {
              'textDocument' => { 'uri' => uri },
              'range' => {
                'start' => { 'line' => 0, 'character' => 0 },
                'end' => { 'line' => last_line, 'character' => 0 },
              },
            },
          })
          outbound.first[:result]
        end

        it 'emits a Type hint for each let-binding' do
          expect(hints.size).to eq 2
          expect(hints).to all(include(kind: 1))
        end

        it 'labels the binding with its inferred type' do
          x_hint = hints.find { it[:position][:line] == 3 }
          expect(x_hint[:label]).to include('Int')
        end

        it 'covers case-of pattern bindings' do
          text = <<~JADE
            module M exposing (run)

            def run(m: Maybe(Int)) -> Int
              case m
              in Just(n) then n
              in Nothing then 0
              end
            end
          JADE
          File.write(File.join(src, 'leaf.jd'), text)
          state, _ = Handlers.dispatch(initialized_state, {
            'method' => 'textDocument/didOpen',
            'params' => { 'textDocument' => { 'uri' => uri, 'text' => text } },
          })
          _, outbound = Handlers.dispatch(state, {
            'method' => 'textDocument/inlayHint',
            'id' => 82,
            'params' => {
              'textDocument' => { 'uri' => uri },
              'range' => {
                'start' => { 'line' => 0, 'character' => 0 },
                'end' => { 'line' => text.lines.size, 'character' => 0 },
              },
            },
          })
          labels = outbound.first[:result].map { it[:label] }
          # `n` inside Just(n) gets a hint
          expect(labels).to include(a_string_including('Int'))
        end

        it 'covers lambda params' do
          text = <<~JADE
            module M exposing (run)

            def run() -> List(Int)
              List.map([1, 2, 3], (x) -> { x + 1 })
            end
          JADE
          File.write(File.join(src, 'leaf.jd'), text)
          state, _ = Handlers.dispatch(initialized_state, {
            'method' => 'textDocument/didOpen',
            'params' => { 'textDocument' => { 'uri' => uri, 'text' => text } },
          })
          _, outbound = Handlers.dispatch(state, {
            'method' => 'textDocument/inlayHint',
            'id' => 83,
            'params' => {
              'textDocument' => { 'uri' => uri },
              'range' => {
                'start' => { 'line' => 0, 'character' => 0 },
                'end' => { 'line' => text.lines.size, 'character' => 0 },
              },
            },
          })
          labels = outbound.first[:result].map { it[:label] }
          expect(labels).to include(a_string_including('Int'))
        end
      end

      describe 'completion' do
        let(:items) do
          _, out = Handlers.dispatch(initialized_state, {
            'method' => 'textDocument/completion',
            'id' => 31,
            'params' => {
              'textDocument' => { 'uri' => uri },
              'position' => { 'line' => 0, 'character' => 0 },
            },
          })
          out.first[:result]
        end

        it 'returns a list of snippet items' do
          expect(items).not_to be_empty
          expect(items).to all(include(insertTextFormat: 2))
        end

        it 'includes structural keyword snippets' do
          expect(items.map { it[:label] }).to include(
            'def', 'type', 'struct', 'case', 'if', 'module',
            'import', 'interface', 'implements', 'uses', 'lambda',
          )
        end

        it 'def snippet closes with end and has tab stops' do
          def_item = items.find { it[:label] == 'def' }
          expect(def_item[:insertText]).to end_with("\nend")
          expect(def_item[:insertText]).to include('${1:')
        end
      end

      describe 'formatting' do
        let(:unformatted) do
          # extra blank line between `module` and `def` is canonical;
          # the leading whitespace before `def` is the drift
          "module M exposing (n)\n\n    def n -> Int\n  42\nend\n"
        end

        def open_and_format(text)
          File.write(File.join(src, 'leaf.jd'), text)
          state, _ = Handlers.dispatch(initialized_state, {
            'method' => 'textDocument/didOpen',
            'params' => { 'textDocument' => { 'uri' => uri, 'text' => text } },
          })
          Handlers.dispatch(state, {
            'method' => 'textDocument/formatting',
            'id' => 91,
            'params' => { 'textDocument' => { 'uri' => uri } },
          })
        end

        it 'returns a single whole-document TextEdit when text drifts' do
          _, outbound = open_and_format(unformatted)
          edits = outbound.first[:result]
          expect(edits.size).to eq 1
          expect(edits.first[:newText]).not_to eq unformatted
        end

        it 'returns an empty array when already formatted' do
          _, outbound = open_and_format(leaf)
          expect(outbound.first[:result]).to eq []
        end

        it 'returns nil when the buffer fails to parse' do
          _, outbound = open_and_format("module M exposing (n)\n\ndef n -> Int\n  if then else end\nend\n")
          expect(outbound.first[:result]).to be_nil
        end
      end

      describe 'unknown method' do
        it 'responds with method-not-found for a request' do
          _, outbound = Handlers.dispatch(State.empty, { 'method' => 'foo/bar', 'id' => 7 })
          expect(outbound.first[:error][:code]).to eq(-32601)
        end

        it 'ignores an unknown notification' do
          _, outbound = Handlers.dispatch(State.empty, { 'method' => 'foo/bar' })
          expect(outbound).to be_empty
        end
      end
    end
  end
end

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

          def n() -> Int
            42
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

            def m() -> Int
              "boom"
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

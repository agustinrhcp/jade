require 'spec_helper'
require 'stringio'
require 'json'

require 'jade/lsp'

module Jade
  module LSP
    describe Server do
      def frame(message)
        body = JSON.generate(message)
        "Content-Length: #{body.bytesize}\r\n\r\n#{body}"
      end

      def parse_frames(text)
        frames = []
        rest = text
        until rest.empty?
          rest =~ /\AContent-Length: (\d+)\r\n\r\n/m or break
          length = $1.to_i
          rest = $'
          frames << JSON.parse(rest[0, length])
          rest = rest[length..] || ''
        end
        frames
      end

      def silence_stderr
        original = $stderr
        $stderr = StringIO.new
        yield
      ensure
        $stderr = original
      end

      it 'reads framed JSON-RPC, dispatches, and writes a framed response' do
        input = StringIO.new(frame({ jsonrpc: '2.0', id: 1, method: 'initialize', params: {} }) + frame({ jsonrpc: '2.0', method: 'exit' }))
        output = StringIO.new
        Server.new(input:, output:).run

        responses = parse_frames(output.string)
        expect(responses.first['id']).to eq 1
        expect(responses.first['jsonrpc']).to eq '2.0'
        expect(responses.first['result']['capabilities']).to include('textDocumentSync')
      end

      it 'returns nil from read on EOF' do
        server = Server.new(input: StringIO.new(''), output: StringIO.new)
        expect { server.run }.not_to raise_error
      end

      it 'survives a handler crash and keeps processing messages' do
        # didChange with empty contentChanges crashes on `last['text']`.
        input = StringIO.new(
          frame({ jsonrpc: '2.0', id: 1, method: 'initialize', params: {} }) +
          frame({ jsonrpc: '2.0', method: 'textDocument/didChange',
                  params: { 'textDocument' => { 'uri' => 'file:///nope' }, 'contentChanges' => [] } }) +
          frame({ jsonrpc: '2.0', id: 2, method: 'shutdown' }) +
          frame({ jsonrpc: '2.0', method: 'exit' })
        )
        output = StringIO.new

        silence_stderr { Server.new(input:, output:).run }

        ids = parse_frames(output.string).map { it['id'] }.compact
        expect(ids).to include(1, 2)
      end
    end
  end
end

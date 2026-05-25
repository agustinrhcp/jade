require 'spec_helper'
require 'jade/lsp'

module Jade
  module LSP
    describe Converters do
      let(:text)   { "let x = 1\nlet y = 2\n" }
      let(:source) { Jade::Source.new(uri: 'foo.jd', text:) }

      describe '.offset_to_position' do
        it 'returns 0/0 at the start' do
          expect(Converters.offset_to_position(source, 0)).to eq(line: 0, character: 0)
        end

        it 'tracks within the first line' do
          expect(Converters.offset_to_position(source, 4)).to eq(line: 0, character: 4)
        end

        it 'crosses the newline' do
          # offset 10 is the 'l' of 'let y' on line 1
          expect(Converters.offset_to_position(source, 10)).to eq(line: 1, character: 0)
        end
      end

      describe '.span_to_range' do
        it 'maps an exclusive Range straight to an LSP half-open range' do
          expect(Converters.span_to_range(source, 4...8)).to eq(
            start: { line: 0, character: 4 },
            end:   { line: 0, character: 8 },
          )
        end
      end

      describe '.relative_path / .lsp_uri' do
        it 'round-trips' do
          root = '/tmp/proj'
          uri  = "file://#{root}/sub/foo.jd"
          rel  = Converters.relative_path(uri, root)
          expect(rel).to eq 'sub/foo.jd'
          expect(Converters.lsp_uri(rel, root)).to eq uri
        end

        it 'decodes percent-escapes from incoming URIs' do
          root = '/tmp/My Project'
          uri  = 'file:///tmp/My%20Project/sub/foo.jd'
          expect(Converters.relative_path(uri, root)).to eq 'sub/foo.jd'
        end

        it 'encodes spaces back when emitting URIs' do
          root = '/tmp/My Project'
          expect(Converters.lsp_uri('sub/foo.jd', root))
            .to eq 'file:///tmp/My%20Project/sub/foo.jd'
        end
      end
    end
  end
end

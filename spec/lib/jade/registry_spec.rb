require 'spec_helper'
require 'tmpdir'
require 'fileutils'

require 'jade'

module Jade
  describe Registry do
    let(:source_root) { Dir.mktmpdir('registry-spec') }
    after { FileUtils.rm_rf(source_root) }

    let(:text) do
      <<~JADE
        module Leaf exposing (n)

        def n(a: Int) -> Int
          a + 1
      JADE
    end

    let(:registry) do
      File.write(File.join(source_root, 'leaf.jd'), text)
      ModuleLoader.load(source_root, 'leaf.jd', tolerant: true)
    end

    describe '#find_node_at' do
      it 'returns the deepest node containing the offset' do
        node = registry.find_node_at('leaf.jd', text.index('a + 1'))
        expect(node).to be_a(AST::VariableReference)
        expect(node.name).to eq('a')
      end

      it 'returns the enclosing node when no child matches the offset' do
        # offset on the leading whitespace before `a + 1` — no child node covers it
        node = registry.find_node_at('leaf.jd', text.index('  a + 1') + 1)
        expect(node).to be_a(AST::FunctionDeclaration)
      end

      it 'returns nil for a uri not in the registry' do
        expect(registry.find_node_at('missing.jd', 0)).to be_nil
      end

      it 'returns nil for an offset past the end of the module' do
        expect(registry.find_node_at('leaf.jd', text.bytesize + 100)).to be_nil
      end
    end
  end
end

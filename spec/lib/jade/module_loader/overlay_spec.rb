require 'spec_helper'
require 'tmpdir'
require 'fileutils'

require 'jade'

module Jade
  describe 'ModuleLoader source overlays' do
    let(:project) { Dir.mktmpdir('jade-overlay-spec') }
    let(:src)     { File.join(project, 'src') }

    before { FileUtils.mkdir_p(src) }
    after  { FileUtils.rm_rf(project) }

    def write(name, body)
      path = File.join(src, "#{name}.jd")
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, body)
    end

    let(:leaf) do
      <<~JADE
        module Leaf exposing (n)

        def n -> Int
          42
      JADE
    end

    let(:root) do
      <<~JADE
        module Root exposing (m)

        import Leaf exposing (n)


        def m -> Int
          n
      JADE
    end

    before do
      write('leaf', leaf)
      write('root', root)
    end

    it 'uses the on-disk source when no overlay is supplied' do
      registry = ModuleLoader.load(src, 'root.jd')
      expect(registry.modules['Leaf'].source.text).to include('42')
    end

    it 'overrides the on-disk source for the entry path' do
      overlay = leaf.sub('42', '99')
      registry = ModuleLoader.load(src, 'leaf.jd', overlays: { 'leaf.jd' => overlay })
      expect(registry.modules['Leaf'].source.text).to include('99')
      expect(registry.modules['Leaf'].source.text).not_to include('42')
    end

    it 'overrides the on-disk source for an imported module' do
      overlay = leaf.sub('42', '7')
      registry = ModuleLoader.load(src, 'root.jd', overlays: { 'leaf.jd' => overlay })

      expect(registry.modules['Leaf'].source.text).to include('7')
      expect(registry.modules['Root']).not_to be_nil
    end

    it 'compiles a module whose on-disk source has a syntax error when an overlay supplies a clean version' do
      write('leaf', 'module Leaf exposing (n)' + "\n\n  garbage")
      overlay = leaf
      registry = ModuleLoader.load(src, 'leaf.jd', overlays: { 'leaf.jd' => overlay })
      expect(registry.modules['Leaf'].generated).to include('def n')
    end
  end
end

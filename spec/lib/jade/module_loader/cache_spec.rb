require 'spec_helper'
require 'tmpdir'
require 'fileutils'

require 'jade'

module Jade
  describe ModuleLoader::Cache do
    let(:project) { Dir.mktmpdir('jade-cache-spec') }
    let(:src)     { File.join(project, 'src') }
    let(:cache)   { File.join(project, '.jade/cache') }
    let(:build)   { File.join(project, '.jade/build') }

    before { FileUtils.mkdir_p(src) }
    after  { FileUtils.rm_rf(project) }

    def write(name, body)
      path = File.join(src, "#{name}.jd")
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, body)
    end

    def compile
      ModuleLoader
        .load(src, 'root.jd', cache_dir: cache)
        .then { ModuleLoader.emit(it, path: build) }
    end

    def cache_mtimes
      Dir["#{cache}/**/*.entry"].sort.to_h { |f| [f, File.mtime(f)] }
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
          n()
      JADE
    end

    before do
      write('leaf', leaf)
      write('root', root)
    end

    it 'writes a .entry file per user module on first compile' do
      compile
      expect(Dir["#{cache}/**/*.entry"].map { File.basename(it) })
        .to contain_exactly('Leaf.entry', 'Root.entry')
    end

    it 'on a no-op rebuild, no cache file is rewritten' do
      compile
      before = cache_mtimes
      sleep 0.01
      compile
      expect(cache_mtimes).to eq(before)
    end

    it 'a private-body edit invalidates only the changed module' do
      compile
      before = cache_mtimes
      sleep 0.01

      write('leaf', leaf.sub('42', '43'))
      compile

      changed = cache_mtimes.reject { |f, m| before[f] == m }
      expect(changed.keys.map { File.basename(it) })
        .to contain_exactly('Leaf.entry')
    end

    it 'an interface change invalidates the module and its consumers' do
      compile
      before = cache_mtimes
      sleep 0.01

      bumped = <<~JADE
        module Leaf exposing (n, two)

        def n -> Int
          42


        def two -> Int
          2
      JADE
      write('leaf', bumped)
      compile

      changed = cache_mtimes.reject { |f, m| before[f] == m }
      expect(changed.keys.map { File.basename(it) })
        .to contain_exactly('Leaf.entry', 'Root.entry')
    end

    it 'an entry compiled fresh and one restored from cache produce the same generated Ruby' do
      compile
      first = File.read(File.join(build, 'root.rb'))

      FileUtils.rm_rf(build)
      compile
      second = File.read(File.join(build, 'root.rb'))

      expect(second).to eq(first)
    end

    describe '.read' do
      let(:entry) { Registry.entry('Test').with(source: Source.new(uri: 't.jd', text: 'x')) }

      it 'returns nil when no cache file exists' do
        expect(described_class.read(cache, 'Test', 'any-key')).to be_nil
      end

      it 'returns nil when the key does not match' do
        described_class.write(cache, 'Test', entry, 'key-a', 'digest-1')
        expect(described_class.read(cache, 'Test', 'key-b')).to be_nil
      end

      it 'returns [entry, interface_digest] when the key matches' do
        described_class.write(cache, 'Test', entry, 'key-a', 'digest-1')
        expect(described_class.read(cache, 'Test', 'key-a'))
          .to eq([entry, 'digest-1'])
      end
    end
  end
end

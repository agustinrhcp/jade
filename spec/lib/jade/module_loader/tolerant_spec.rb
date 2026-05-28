require 'spec_helper'
require 'tmpdir'
require 'fileutils'

require 'jade'

module Jade
  describe 'ModuleLoader tolerant mode' do
    let(:project) { Dir.mktmpdir('jade-tolerant-spec') }
    let(:src)     { File.join(project, 'src') }

    before { FileUtils.mkdir_p(src) }
    after  { FileUtils.rm_rf(project) }

    def write(name, body)
      path = File.join(src, "#{name}.jd")
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, body)
    end

    let(:broken) do
      <<~JADE
        module Broken exposing (oops)

        def oops -> Int
          "not an int"
        end
      JADE
    end

    before { write('broken', broken) }

    it 'raises by default when a module fails to type-check' do
      expect { ModuleLoader.load(src, 'broken.jd') }
        .to raise_error(CompilationError)
    end

    it 'carries a structured Diagnostics::List on the raised error' do
      ModuleLoader.load(src, 'broken.jd')
    rescue CompilationError => e
      expect(e.diagnostics).to be_a(Diagnostics::List)
      expect(e.diagnostics.items).not_to be_empty
      expect(e.diagnostics.items.first).to be_a(Diagnostics::Diagnostic)
      expect(e.diagnostics.items.first).to be_error
    end

    it 'carries diagnostics for a parse error too' do
      write('syntax_broken', "module SyntaxBroken exposing (x)\n\ndef x ->")

      ModuleLoader.load(src, 'syntax_broken.jd')
    rescue CompilationError => e
      expect(e.diagnostics.items).not_to be_empty
      expect(e.diagnostics.items.first).to be_a(Diagnostics::Diagnostic)
    end

    it 'in tolerant mode returns a registry with the failed entry holding diagnostics' do
      registry = ModuleLoader.load(src, 'broken.jd', tolerant: true)
      entry    = registry.modules['Broken']

      expect(entry).not_to be_nil
      expect(entry.diagnostics.items).not_to be_empty
      expect(entry.diagnostics.items.first).to be_a(Diagnostics::Diagnostic)
      expect(entry.diagnostics.items.first).to be_error
    end

    it 'compiles a clean module with no diagnostics in tolerant mode' do
      write('ok', <<~JADE)
        module Ok exposing (n)

        def n -> Int
          42
        end
      JADE

      registry = ModuleLoader.load(src, 'ok.jd', tolerant: true)
      expect(registry.modules['Ok'].diagnostics.items).to be_empty
    end

    it 'continues past an upstream tolerant failure and surfaces a diagnostic on the consumer too' do
      write('consumer', <<~JADE)
        module Consumer exposing (run)

        import Broken exposing (oops)


        def run -> Int
          oops()
        end
      JADE

      registry = ModuleLoader.load(src, 'consumer.jd', tolerant: true)

      expect(registry.modules['Broken'].diagnostics.items).not_to be_empty
      expect(registry.modules['Consumer'].diagnostics.items).not_to be_empty
    end
  end
end

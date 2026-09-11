require 'fileutils'
require 'tmpdir'

module Jade
  module Repl
    # Where cells become Ruby: compiled against the session's overlays,
    # emitted into a scratch directory, and required one file per cell. A
    # cell that raises while its values are forced is unloaded again, so
    # nothing of it outlives the rejection.
    Host = Data.define(:source_root, :space, :dir) do
      def self.create(source_root:, space:)
        File.realpath(Dir.mktmpdir('jade-repl')).then do |dir|
          new(source_root: source_root || make(File.join(dir, 'src')), space:, dir:)
        end
      end

      def self.make(path)
        FileUtils.mkdir_p(path).first
      end

      def compile(overlays, cells, uri)
        ModuleLoader
          .load(source_root, uri, overlays:, cells:, cache_dir: File.join(dir, 'cache'))
          .then { Ok[it] }
      rescue CompilationError => e
        Err[e.diagnostics]
      end

      def run(registry, cell, forced)
        ModuleLoader.emit(registry, path: build)
        require path(cell)

        forced
          .to_h { |name, task| [name, force(internal(cell), name, task)] }
          .then { Ok[it] }
      rescue StandardError, SystemStackError, Interrupt => e
        unload(cell)
        Err[e]
      end

      def clean
        FileUtils.rm_rf(dir)
      end

      private

      def force(internal, name, task)
        internal
          .public_send(name)
          .then { task ? it.run : it }
      end

      def internal(cell)
        Object.const_get("#{cell.module_name.gsub('.', '::')}::Internal")
      end

      def unload(cell)
        $LOADED_FEATURES.delete(path(cell))

        cell.module_name.split('.').then do |(namespace, name)|
          next unless Object.const_defined?(namespace)

          Object
            .const_get(namespace)
            .then { it.send(:remove_const, name) if it.const_defined?(name, false) }
        end
      end

      def build
        File.join(dir, 'build')
      end

      def path(cell)
        File.join(build, cell.uri.sub(/\.jd\z/, '.rb'))
      end
    end
  end
end

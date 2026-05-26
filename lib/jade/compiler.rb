module Jade
  class Compiler
    attr_reader :config

    def initialize
      yield(config) if block_given?
    end

    def require(path)
      target = File.expand_path("#{build_root}/#{path}.rb", config.project_root)

      if needs_rebuild?(target)
        ModuleLoader
          .load(config.source_root.first, path + '.jd', cache_dir: cache_root)
          .tap { render_diagnostics(it) }
          .then { ModuleLoader.emit(it, path: build_root) }
      end

      Kernel.require(File.realpath(target))
    end

    private

    def render_diagnostics(registry)
      registry
        .modules
        .each_value
        .reject { Stdlib.is_stdlib?(it) }
        .reject { it.diagnostics.items.empty? }
        .each { $stderr.puts Diagnostics::Renderer.new.render_all(it.diagnostics) }
    end

    def config
      @config ||= Config.new
    end

    def build_root
      File.expand_path(config.build_dir, config.project_root)
    end

    def cache_root
      File.expand_path(config.cache_dir, config.project_root)
    end

    def needs_rebuild?(target)
      return true unless File.exist?(target)

      target_mtime = File.mtime(target)
      Dir
        .glob(File.join(config.source_root.first, '**/*.jd'))
        .any? { |src| File.mtime(src) > target_mtime }
    end

    class Config
      attr_accessor :project_root, :source_root, :build_dir, :cache_dir

      def initialize
        @project_root = Dir.pwd
        @source_root = []
        @build_dir   = ".jade/build"
        @cache_dir   = ".jade/cache"
      end

      def source_root=(root)
        @source_root = Array(root)
      end
    end
  end
end

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
          .load(config.source_root, path + '.jd', cache_dir: cache_root)
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
        .glob(File.join(config.source_root, '**/*.jd'))
        .any? { |src| File.mtime(src) > target_mtime }
    end

    class Config
      attr_accessor :project_root, :source_root, :build_dir, :cache_dir

      # Seeded from jade.json when there is one, so `Jade.setup` needs only
      # what the manifest doesn't say. A setup block still wins — it runs
      # after this.
      def initialize(project = Project.find)
        @project_root = project&.root || Dir.pwd
        @source_root = project&.source_root
        @build_dir = project&.build_dir || ".jade/build"
        @cache_dir = project&.cache_dir || ".jade/cache"
      end

      # One root. A list was accepted but only ever read at `.first`, so
      # anything past the first was silently dropped — say so instead.
      def source_root=(root)
        Array(root).then do
          fail ArgumentError, "source_root takes one root, got #{it.size}" if it.size > 1

          @source_root = it.first
        end
      end
    end
  end
end

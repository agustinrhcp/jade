module Jade
  class Compiler
    attr_reader :config

    def initialize
      @loaded = {}
      yield(config) if block_given?
    end

    def require(path)
      return false if @loaded[path]

      ModuleLoader
        .load(config.source_root.first, path + '.jd')
        .then { ModuleLoader.emit(it, path: build_root) }

      compiled_path = File.expand_path(
        "#{build_root}/#{path}.rb",
        config.project_root,
      )

      load compiled_path
      @loaded[path] = true
    end

    private 

    def config
      @config ||= Config.new
    end

    def build_root
      File.expand_path(config.build_dir, config.project_root)
    end

    class Config
      attr_accessor :project_root, :source_root, :build_dir

      def initialize
        @project_root = Dir.pwd
        @source_root = []
        @build_dir   = ".jade/build"
      end

      def source_root=(root)
        @source_root = Array(root)
      end
    end
  end
end

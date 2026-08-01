require "tmpdir"
require_relative "format_check"

module Jade
  class TestCompiler
    @@compiled = {}

    attr_reader :compiler

    def initialize
      @project_root = Dir.mktmpdir("jade-spec")
      @source_root  = File.join(@project_root, "src")
      @build_root   = File.join(@project_root, ".jade", "build")
      @written      = {}

      FileUtils.mkdir_p(@source_root)
      FileUtils.mkdir_p(@build_root)

      @compiler = Compiler.new do |c|
        c.source_root  = @source_root
        c.project_root = @project_root
      end
    end

    # The compiler derives a module's name back from its path (Source.camelize,
    # which is capitalize-based), so only a snake_case path round-trips:
    # `debug_probe.jd` -> DebugProbe, but `DebugProbe.jd` -> Debugprobe. Name
    # the file for the module rather than after it, or generated code
    # self-references a constant that was never defined.
    def path_for(module_name)
      module_name.split('.').map { Source.snake_case(it) }.join('/')
    end

    def write(module_name, source)
      path = File.join(@source_root, "#{path_for(module_name)}.jd")
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, source)
      @written[module_name] = source
    end

    def require(module_name, source)
      FormatCheck.assert!(source, label: module_name) unless ENV['JADE_SKIP_FORMAT_CHECK']
      write(module_name, source)

      key    = [module_name, @written.sort].freeze
      rb_file = File.join(@build_root, "#{path_for(module_name)}.rb")

      if @@compiled.include?(key) && File.exist?(rb_file)
        return
      end

      silence_warnings { compiler.require(path_for(module_name)) }

      raise "Expected #{rb_file} to exist" unless File.exist?(rb_file)

      @@compiled[key] = true
    end

    def cleanup
      FileUtils.rm_rf(@project_root)
    end

    def generated_source(module_name)
      File.read(File.join(@build_root, "#{path_for(module_name)}.rb"))
    end

    private

    def silence_warnings
      old_verbose = $VERBOSE
      $VERBOSE = nil
      yield
    ensure
      $VERBOSE = old_verbose
    end
  end
end

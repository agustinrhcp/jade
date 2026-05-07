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

    def write(module_name, source)
      path = File.join(@source_root, "#{module_name}.jd")
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, source)
      @written[module_name] = source
    end

    def require(module_name, source)
      FormatCheck.assert!(source, label: module_name) unless ENV['JADE_SKIP_FORMAT_CHECK']
      write(module_name, source)

      key = [module_name, @written.sort].freeze
      return if @@compiled.include?(key)

      silence_warnings { compiler.require(module_name) }

      rb_file = File.join(@build_root, "#{module_name}.rb")
      raise "Expected #{rb_file} to exist" unless File.exist?(rb_file)

      @@compiled[key] = true
    end

    def cleanup
      FileUtils.rm_rf(@project_root)
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

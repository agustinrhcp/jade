require 'fileutils'
require 'rbconfig'
require 'stringio'
require 'tmpdir'

require 'jade/cli/eject'

module Jade
  # A project ejected into a temp directory, and a way to run Ruby against
  # it in a process that has no jade on its load path.
  class EjectedProject
    EXAMPLES = File.expand_path('../../examples', __dir__)

    def initialize(sources)
      @root = Dir.mktmpdir('jade-ejected')

      FileUtils.mkdir_p(lib)
      File.write(File.join(@root, 'jade.json'), '{ "source_roots": ["lib"] }')
      sources.each { |name, text| write(name, text) }

      Dir.chdir(@root) { quietly { CLI::Eject.run([]) } }
    end

    def self.from_examples(*names, **extra)
      names
        .to_h { [it, File.read(File.join(EXAMPLES, "#{it}.jd"))] }
        .merge(extra)
        .then { new(it) }
    end

    # Prints the expression, so the caller gets a string back.
    def run(*requires, expression)
      requires
        .map { "require_relative #{it.to_s.inspect}" }
        .join('; ')
        .then { [RbConfig.ruby, '-e', "#{it}; print(#{expression})"] }
        .then { capture(it) }
    end

    def files
      Dir.glob(File.join(@root, 'ejected', '**', '*.rb'))
    end

    def cleanup
      FileUtils.rm_rf(@root)
    end

    private

    def lib
      File.join(@root, 'lib')
    end

    def write(name, text)
      File.write(File.join(lib, "#{name}.jd"), text)
    end

    def capture(command)
      IO
        .popen(command, chdir: File.join(@root, 'ejected'), err: [:child, :out], &:read)
        .tap { fail it unless $?.success? }
    end

    def quietly
      $stdout = StringIO.new
      yield
    ensure
      $stdout = STDOUT
    end
  end
end

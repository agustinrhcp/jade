require 'fileutils'
require 'rbconfig'

require 'jade'
require 'jade/module_loader'

module Jade
  module CLI
    # Writes the project as Ruby that runs without the gem: the compiled
    # modules, the runtime they call, and requires that point at each other
    # rather than at a load path.
    module Eject
      module_function

      DEFAULT_OUT = 'ejected'.freeze

      def run(argv)
        usage if argv.any? { it == '-h' || it == '--help' }

        Project
          .find!
          .then { [it, out_dir(argv, it)] }
          .then { |project, out| eject(project, out) }
      end

      def eject(project, out)
        FileUtils.rm_rf(out)

        compile_all(project, out)
        vendor_runtime(out)
        rewrite_requires(out)

        report(out)
      end

      # Every module, not only the ones something imports: an ejected tree
      # that drops a file is not the project.
      def compile_all(project, out)
        sources(project).each do |entry|
          ModuleLoader
            .load(project.source_root, entry, cache_dir: project.cache_path)
            .then { ModuleLoader.emit(it, path: out) }
        end
      end

      def sources(project)
        Dir
          .glob(File.join(project.source_root, '**', '*.jd'))
          .map { Pathname.new(it).relative_path_from(Pathname.new(project.source_root)).to_s }
          .sort
      end

      # Whatever a booted runtime loads is what the ejected code needs, so
      # ask one rather than keeping a list here.
      def vendor_runtime(out)
        runtime_files.each do |file|
          File.join(out, file)
            .tap { FileUtils.mkdir_p(File.dirname(it)) }
            .then { FileUtils.cp(File.join(gem_lib, file), it) }
        end
      end

      def runtime_files
        [RbConfig.ruby, '-I', gem_lib, '-e', BOOT]
          .then { IO.popen(it, err: [:child, :out], &:read) }
          .lines(chomp: true)
          .select { it.start_with?("#{gem_lib}/") }
          .map { it.delete_prefix("#{gem_lib}/") }
      end

      BOOT = "require 'jade/runtime'; Jade::Runtime.boot!; puts $LOADED_FEATURES".freeze

      def gem_lib
        File.expand_path('../../..', __dir__).then { File.join(it, 'lib') }
      end

      # `require 'jade/x'` finds the gem; the point is not to have one.
      def rewrite_requires(out)
        Dir
          .glob(File.join(out, '**', '*.rb'))
          .each { rewrite(it, out) }
      end

      def rewrite(path, out)
        File
          .read(path)
          .gsub(/^\$LOAD_PATH\.push\(File\.expand_path\("lib"\)\)\.uniq!\n/, '')
          .gsub(/require ['"](jade\/[a-z_\/]+)['"]/) { "require_relative '#{up_to(path, out)}#{$1}'" }
          .then { File.write(path, it) }
      end

      def up_to(path, out)
        Pathname
          .new(out)
          .expand_path
          .relative_path_from(Pathname.new(File.dirname(File.expand_path(path))))
          .then { it.to_s == '.' ? '' : "#{it}/" }
      end

      def report(out)
        puts <<~TXT
          Ejected to #{out}/ (#{Dir.glob(File.join(out, '**', '*.rb')).size} files).

          Nothing under #{out}/ requires the jade gem. To leave:

            1. point your app at #{out}/ instead of the build directory
            2. run your suite
            3. drop jade-lang from your Gemfile and delete the .jd sources
        TXT
      end

      def out_dir(argv, project)
        argv
          .each_cons(2)
          .find { |flag, _| flag == '--out' }
          &.last
          .then { File.expand_path(it || DEFAULT_OUT, project.root) }
      end

      def usage
        warn <<~USAGE
          Usage: jade eject [--out DIR]

          Compiles the project and writes it, plus the runtime it calls, as
          Ruby that does not require the jade gem. Writes to ./ejected by
          default. The directory is replaced if it exists.
        USAGE
        exit 1
      end
    end
  end
end

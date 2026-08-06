require 'jade'
require 'jade/module_loader'
require 'jade/diagnostics/renderer'

module Jade
  module CLI
    # Type-checks without generating anything.
    module Check
      module_function

      def run(argv)
        usage if argv.any? { it == '-h' || it == '--help' }

        Project
          .find!
          .then { report(diagnose(it, argv), it) }
      end

      def diagnose(project, files)
        entries(project, files)
          .flat_map { compile(project, it) }
          .uniq { |d| [d.primary&.source&.uri, d.message, d.primary&.span] }
      end

      def entries(project, files)
        return sources(project) if files.empty?

        files.map { project.source_relative(it) }
      end

      def sources(project)
        Dir
          .glob(File.join(project.source_root, '**', '*.jd'))
          .map { Pathname.new(it).relative_path_from(project.source_root).to_s }
          .sort
      end

      # Tolerant, so a module yields every diagnostic rather than the first.
      def compile(project, entry)
        ModuleLoader
          .load(project.source_root, entry, cache_dir: project.cache_path, tolerant: true)
          .then { collect(it) }
      rescue CompilationError => e
        e.diagnostics.items
      end

      def collect(registry)
        registry
          .modules
          .each_value
          .reject { Stdlib.is_stdlib?(it) }
          .reject { it.source.nil? }
          .flat_map { it.diagnostics.items }
      end

      def report(items, project)
        return if items.empty?

        Diagnostics::Renderer
          .new(colors: $stdout.tty?)
          .render_all(Diagnostics::List.new(items:))
          .then { warn(it) }

        warn(summary(items, project))
        exit 1 if items.any?(&:error?)
      end

      def summary(items, project)
        items
          .partition(&:error?)
          .then { |(errors, rest)| [count(errors, 'error'), count(rest, 'warning')] }
          .compact
          .join(', ')
          .then { "\n#{it} in #{project.source_roots.first}" }
      end

      def count(items, noun)
        return nil if items.empty?

        "#{items.size} #{noun}#{'s' unless items.size == 1}"
      end

      def usage
        warn <<~USAGE
          Usage: jade check [FILE...]

          Type-checks FILEs and everything they import, writing diagnostics
          to stderr. Checks every .jd file under the source root when given
          no arguments. Exits 1 if there were errors, 0 otherwise.

          FILE is relative to the project root or the source root.
        USAGE
        exit 1
      end
    end
  end
end

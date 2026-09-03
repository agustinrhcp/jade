require 'fileutils'
require 'json'

require 'jade'

module Jade
  module CLI
    # Writes the manifest every tool outside the app reads. Without one,
    # the CLI and the language server have to guess where the sources are,
    # which is why `Project::NotFound` says to write this file by hand.
    module Init
      module_function

      IGNORED = '.jade/'.freeze

      def run(argv)
        usage if argv.any? { it == '-h' || it == '--help' }

        source_root(argv)
          .then { [it, File.expand_path(Project::MANIFEST)] }
          .then { |root, manifest| write(root, manifest) }
      end

      def write(root, manifest)
        refuse(manifest) if File.exist?(manifest)

        File.write(manifest, "#{JSON.pretty_generate(config(root))}\n")
        FileUtils.mkdir_p(root)

        report(root, manifest)
      end

      # Only what the defaults do not already say. A manifest naming every
      # setting reads as though each were a decision.
      def config(root)
        { 'source_roots' => [root], 'extensions' => [] }
      end

      def source_root(argv)
        argv
          .each_cons(2)
          .find { |flag, _| flag == '--source-root' }
          &.last || Project::DEFAULTS[:source_roots].first
      end

      def refuse(manifest)
        warn "jade: #{File.basename(manifest)} already exists in #{File.dirname(manifest)}"
        exit 1
      end

      def report(root, manifest)
        puts <<~TXT
          Wrote #{File.basename(manifest)} and #{root}/.

          Put a module in #{root}/, then:

            jade check              type-check it
            jade fmt #{root}/x.jd#{' ' * [0, 7 - root.length].max}   format it

          #{gitignore_note}
        TXT
      end

      # Build and cache output, which nobody wants in a diff.
      def gitignore_note
        path = File.expand_path('.gitignore')
        return "Add #{IGNORED} to .gitignore." unless File.exist?(path)
        return "#{IGNORED} is already ignored." if File.read(path).match?(/^\.jade\b/)

        File.write(path, "#{File.read(path).chomp}\n#{IGNORED}\n")
        "Added #{IGNORED} to .gitignore."
      end

      def usage
        warn <<~USAGE
          Usage: jade init [--source-root DIR]

          Writes jade.json, which is how every tool outside the app finds
          your sources, and creates the source directory. Refuses to
          overwrite an existing manifest.
        USAGE
        exit 1
      end
    end
  end
end

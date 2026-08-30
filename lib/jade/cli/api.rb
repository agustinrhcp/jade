require 'json'

require 'jade'
require 'jade/api'

module Jade
  module CLI
    # The public surface as data: what a snapshot in CI compares, and what
    # a docs page or an editor can read.
    module Api
      module_function

      DEFAULT_FILE = 'jade-api.json'.freeze

      def run(argv)
        usage if argv.any? { it == '-h' || it == '--help' }

        surface(argv)
          .then { |json| argv.include?('--check') ? check(json, file(argv)) : write(json, argv) }
      end

      def surface(argv)
        Jade::Api
          .load
          .surface(origins: origins(argv))
          .then { JSON.pretty_generate(it) + "\n" }
      end

      def check(json, path)
        return if File.exist?(path) && File.read(path) == json

        warn("#{path} is out of date. Regenerate it with `jade api --out #{path}`.")
        warn(diff(File.exist?(path) ? File.read(path) : '', json))
        exit 1
      end

      def write(json, argv)
        return puts(json) unless argv.include?('--out')

        file(argv)
          .then { File.write(it, json) }
      end

      def diff(before, after)
        (before.lines - after.lines).map { "- #{it}" }
          .then { it + (after.lines - before.lines).map { "+ #{it}" } }
          .join
      end

      def file(argv)
        flag_value(argv, '--out') || flag_value(argv, '--check') || DEFAULT_FILE
      end

      def origins(argv)
        flag_value(argv, '--origin')&.split(',')
      end

      def flag_value(argv, flag)
        argv
          .each_cons(2)
          .find { |name, value| name == flag && !value.start_with?('--') }
          &.last
      end

      def usage
        warn <<~USAGE
          Usage: jade api [--origin O[,O]] [--out FILE] [--check [FILE]]

          Prints every name a program can depend on, with its shape, as JSON.
          Interface members are listed separately, since adding one breaks
          every implementation without changing a signature.

            --origin  project, extension or stdlib. All of them by default.
            --out     write to FILE instead of stdout
            --check   compare FILE against the current surface, exit 1 if it
                      moved. FILE defaults to #{DEFAULT_FILE}.
        USAGE
        exit 1
      end
    end
  end
end

require 'jade'
require 'jade/tasks'
require 'jade/testing/runner'
require 'jade/testing/reporter'

module Jade
  module CLI
    module Test
      USAGE = <<~TXT.freeze
        Usage: jade test [-f dots|doc] [PATTERN...]

          Runs every `*_test.jd` module under the project's source root.
          PATTERN filters those by substring, against path or module name.

          -f, --format  `dots` (default) prints one mark per test; `doc`
                        prints the tree of names.

        A test module exposes `tests`:

          module MathTest exposing (tests)

          import Test exposing (Test, context, describe, it)
          import Expect


          def tests -> Test
            describe(
              "Math",
              [
                it("adds", -> { Expect.equal(1 + 1, 2) }),
                context("negatives", [
                  it("subtracts", -> { Expect.equal(1 - 2, 0 - 1) }),
                ]),
              ],
            )
          end

        Order is stable — no seed, no shuffle — and ports are unavailable, so
        a passing run says the same thing tomorrow.
      TXT

      SUFFIX = '_test.jd'.freeze

      class EffectAttempted < StandardError
        def initialize(task_def)
          super(
            "#{task_def} was called. `jade test` runs pure tests only: nothing " \
              "stubs a port yet, so a test that reaches one would depend on the " \
              "world. Keep effectful tests in RSpec."
          )
        end
      end

      # Nondeterminism lives at the ports — the clock and id generation as
      # much as the database — so the seam is taken away, not trusted.
      module PureOnly
        def dispatch(task_def, *_args)
          fail EffectAttempted.new(task_def)
        end
      end

      module_function

      def run(argv)
        return puts(USAGE) if argv.intersect?(%w[-h --help])

        Jade::Tasks.singleton_class.prepend(PureOnly)

        parse(argv).then do |(format, patterns)|
          Jade::Project.find!.then do |project|
            discover(project, patterns)
              .then { it.empty? ? no_tests(project, patterns) : execute(project, it, format) }
          end
        end
      end

      FORMATS = { 'dots' => :dots, 'doc' => :doc }.freeze

      def parse(argv)
        case argv
        in [*head, ('-f' | '--format'), name, *tail] then [format_named(name), head + tail]
        else [:dots, argv]
        end
      end

      def format_named(name)
        FORMATS.fetch(name) do
          warn "jade test: unknown format #{name.inspect} (want #{FORMATS.keys.join(' or ')})"
          exit 1
        end
      end

      def execute(project, uris, format = :dots)
        started = now
        broken, loaded = load_all(uris)
        compiled = now

        results = loaded.flat_map { Testing::Runner.run(it) }

        Testing::Reporter
          .new(format:)
          .report(results, broken, Testing::Timing[compiled - started, now - compiled])

        exit 1 unless broken.empty? && results.all? { Testing::Passed === it }
      end

      def discover(project, patterns)
        Dir
          .glob("**/*#{SUFFIX}", base: project.source_root)
          .sort
          .select { |uri| patterns.empty? || matches?(uri, patterns) }
      end

      def matches?(uri, patterns)
        [uri, module_name(uri)]
          .then { |names| patterns.any? { |p| names.any? { it.include?(p) } } }
      end

      def load_all(uris)
        Jade::Compiler
          .new
          .then { |compiler| uris.map { load_one(compiler, it) } }
          .partition { Testing::Broken === it }
      end

      def load_one(compiler, uri)
        module_name(uri)
          .then { [it, compile(compiler, uri, it)] }
          .then { |(name, mod)| Testing::Runner.runnable?(mod) ? mod : unrunnable(name, mod) }
      rescue NameError => e
        # A failed type check can leave an empty file, so requiring it succeeds
        # and the constant is simply absent. The diagnostics are already printed.
        Testing::Broken[module_name(uri), RuntimeError.new(did_not_compile(e))]
      rescue StandardError => e
        Testing::Broken[module_name(uri), e]
      end

      def did_not_compile(error)
        "did not compile — see the errors above (#{error.message})"
      end

      def compile(compiler, uri, name)
        compiler
          .require(uri.delete_suffix('.jd'))
          .then { Object.const_get(name.gsub('.', '::')) }
      end

      def unrunnable(name, mod)
        Testing::Broken[name, RuntimeError.new(Testing::Runner.why_unrunnable(mod))]
      end

      def module_name(uri)
        uri
          .delete_suffix('.jd')
          .split('/')
          .map { Source.camelize(it) }
          .join('.')
      end

      def no_tests(project, patterns)
        warn <<~TXT
          jade test: no #{patterns.empty? ? '' : "matching "}test modules under #{project.source_root}

          Test modules are files named `*#{SUFFIX}`. Run `jade test --help` for the shape of one.
        TXT
        exit 1
      end

      def now
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end
    end
  end
end

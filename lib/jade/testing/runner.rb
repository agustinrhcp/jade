require 'jade/testing/results'

module Jade
  module Testing
    # `Internal` is the only side of a generated module that hands the
    # values over: `Test` has no Encodable instance, and a thunk never can.
    module Runner
      extend self

      def run(mod)
        outcomes(mod::Internal.tests, [mod.name.gsub('::', '.')])
      end

      MISSING = 'no `tests` function — a test module exposes `tests -> Test`'.freeze

      def runnable?(mod)
        mod.const_defined?(:Internal) && mod::Internal.respond_to?(:tests)
      end

      # `tests` lands outside `Internal` when a constraint in it went
      # unresolved, and only the public wrapper is left to say why.
      def why_unrunnable(mod)
        mod.tests
        MISSING
      rescue ::Jade::Interop::NotExposed => e
        "`tests` did not compile to a value: #{e.message}"
      rescue NoMethodError
        MISSING
      end

      private

      def outcomes(test, path)
        case test
        in ::Test::Group(name, children)
          children.flat_map { outcomes(it, path + [name]) }

        in ::Test::Unit(name, body)
          [outcome(path + [name], body)]
        end
      end

      def outcome(path, body)
        case body.call
        in ::Expect::Pass then Passed[path]
        in ::Expect::Fail(reasons) then Failed[path, reasons]
        end
      rescue StandardError => e
        Crashed[path, e]
      end
    end
  end
end

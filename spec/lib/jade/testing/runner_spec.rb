require 'spec_helper'

require 'jade'
require 'jade/testing/runner'

module Jade
  module Testing
    describe Runner do
      let(:compiler) { TestCompiler.new }

      def build(name, tests)
        compiler.require(<<~JADE)
          module #{name} exposing (tests)

          import Test exposing (Test, context, describe, it)
          import Expect


          def tests -> Test
            #{tests.strip.gsub("\n", "\n  ")}
          end
        JADE

        Object.const_get(name)
      end

      it 'walks the tree depth first, naming each test by its path' do
        mod = build('WalkTest', <<~JADE)
          describe(
            "outer",
            [
              it("first", -> { Expect.true(True) }),
              context("inner", [
                it("second", -> { Expect.true(True) }),
              ]),
              it("third", -> { Expect.true(True) }),
            ],
          )
        JADE

        expect(Runner.run(mod).map(&:path)).to eql [
          %w[WalkTest outer first],
          %w[WalkTest outer inner second],
          %w[WalkTest outer third],
        ]
      end

      it 'reports each failure with the reasons the expectation carried' do
        mod = build('FailingTest', <<~JADE)
          describe(
            "math",
            [
              it("passes", -> { Expect.equal(1, 1) }),
              it("fails", -> { Expect.equal(1, 2) }),
            ],
          )
        JADE

        passed, failed = Runner.run(mod)

        expect(passed).to be_a Passed
        expect(failed).to be_a Failed
        expect(failed.reasons.map(&:expected)).to eql ['2']
      end

      it 'contains a crash to the test that caused it' do
        mod = build('CrashingTest', <<~JADE)
          describe(
            "math",
            [
              it("divides by zero", -> { Expect.equal(1 / 0, 1) }),
              it("still runs", -> { Expect.true(True) }),
            ],
          )
        JADE

        crashed, after = Runner.run(mod)

        expect(crashed).to be_a Crashed
        expect(crashed.error).to be_a ZeroDivisionError
        expect(after).to be_a Passed
      end

      it 'knows a module it cannot run' do
        expect(Runner.runnable?(build('RunnableTest', 'describe("m", [])'))).to be true
        expect(Runner.runnable?(Module.new)).to be false
      end

      it 'explains a module whose tests never became a value' do
        mod = Module.new do
          def self.tests(*)
            raise Interop::NotExposed.new(
              module_name: 'X', function_name: :tests, hint: 'polymorphic',
            )
          end
        end

        expect(Runner.why_unrunnable(mod)).to match(/did not compile to a value/)
        expect(Runner.why_unrunnable(Module.new)).to eql Runner::MISSING
      end
    end
  end
end

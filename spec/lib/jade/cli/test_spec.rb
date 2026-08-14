require 'spec_helper'

require 'fileutils'
require 'stringio'
require 'tmpdir'

require 'jade/cli/test'

module Jade
  module CLI
    describe Test do
      let(:root) { Dir.mktmpdir('jade-cli-test') }

      before do
        write('jade.json', '{ "source_roots": ["lib"] }')
        write('lib/math.jd', <<~JADE)
          module Math exposing (add)

          def add(a: Int, b: Int) -> Int
            a + b
          end
        JADE
      end

      after { FileUtils.rm_rf(root) }

      def write(path, contents)
        File.join(root, path).then do |full|
          FileUtils.mkdir_p(File.dirname(full))
          File.write(full, contents)
        end
      end

      def test_module(name, body)
        write("lib/#{Source.snake_case(name)}.jd", <<~JADE)
          module #{name} exposing (tests)

          import Test exposing (Test, describe, it)
          import Expect
          import Math


          def tests -> Test
            #{body.strip.gsub("\n", "\n  ")}
          end
        JADE
      end

      Run = Data.define(:output, :status)

      def execute(*patterns, format: :doc)
        captured = StringIO.new
        stdout = $stdout
        $stdout = captured
        status = 0

        begin
          Dir.chdir(root) do
            Project.find!.then { Test.execute(it, Test.discover(it, patterns), format) }
          end
        rescue SystemExit => e
          status = e.status
        end

        Run[captured.string, status]
      ensure
        $stdout = stdout
      end

      it 'runs the tests it finds and says so' do
        test_module('MathTest', 'describe("Math", [it("adds", -> { Expect.equal(Math.add(1, 2), 3) })])')

        execute.then do |run|
          expect(run.output).to include('. adds').and include('1 test, 0 failures')
          expect(run.status).to eql 0
        end
      end

      it 'exits non-zero when a test fails, and shows why' do
        test_module('MathTest', 'describe("Math", [it("adds", -> { Expect.equal(Math.add(1, 2), 4) })])')

        execute.then do |run|
          expect(run.status).to eql 1
          expect(run.output).to include('expected values to be equal')
          expect(run.output).to include('expected: 4')
        end
      end

      it 'discovers every test module under the source root, in a stable order' do
        test_module('BTest', 'describe("b", [])')
        test_module('ATest', 'describe("a", [])')
        write('lib/helpers.jd', "module Helpers exposing (n)\n\ndef n -> Int\n  1\nend\n")

        Dir.chdir(root) do
          expect(Test.discover(Project.find!, [])).to eql %w[a_test.jd b_test.jd]
        end
      end

      it 'runs a test module nested under a directory' do
        write('lib/deep/math_test.jd', <<~JADE)
          module Deep.MathTest exposing (tests)

          import Test exposing (Test, describe, it)
          import Expect


          def tests -> Test
            describe("Deep", [it("adds", -> { Expect.equal(1 + 1, 2) })])
          end
        JADE

        execute.then do |run|
          expect(run.output).to include('Deep.MathTest').and include('. adds')
          expect(run.output).not_to include('Deep::MathTest')
          expect(run.status).to eql 0
        end
      end

      it 'filters by pattern, against path or module name' do
        test_module('BTest', 'describe("b", [])')
        test_module('ATest', 'describe("a", [])')

        Dir.chdir(root) do
          expect(Test.discover(Project.find!, ['ATest'])).to eql %w[a_test.jd]
          expect(Test.discover(Project.find!, ['b_test'])).to eql %w[b_test.jd]
        end
      end

      it 'reports a module that does not compile without taking the run down' do
        test_module('GoodTest', 'describe("good", [it("passes", -> { Expect.true(True) })])')
        write('lib/bad_test.jd', <<~JADE)
          module BadTest exposing (tests)

          import Test exposing (Test)


          def tests -> Test
            nonexistent_thing
          end
        JADE

        execute.then do |run|
          expect(run.output).to include('. passes')
          expect(run.output).to include('BadTest')
          expect(run.output).to include('1 test, 0 failures, 1 error')
          expect(run.status).to eql 1
        end
      end

      it 'prints one mark per test unless asked for names' do
        test_module('MathTest', 'describe("Math", [it("adds", -> { Expect.equal(1 + 1, 2) })])')

        expect(execute(format: :dots).output).to start_with(".\n")
      end

      it 'reads the format off the command line' do
        expect(Test.parse(['-f', 'doc', 'MathTest'])).to eql [:doc, ['MathTest']]
        expect(Test.parse(['MathTest'])).to eql [:dots, ['MathTest']]
      end

      it 'refuses a test that reaches for a port' do
        Object.new.extend(Test::PureOnly).then do |dispatcher|
          expect { dispatcher.dispatch(TaskDef['Crypto::Runtime', 'hash']) }
            .to raise_error(Test::EffectAttempted, /pure tests only/)
        end
      end
    end
  end
end

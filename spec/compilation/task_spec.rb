require 'spec_helper'

require 'jade'
require 'jade/module_loader'

module Jade
  describe 'Task' do
    include_context 'with test compiler'

    let(:source) do
      <<~JADE
        module TaskTest exposing (always_err, always_ok, chained, chained_err, mapped)

        def always_ok -> Task(Int, String)
          Task.succeed(42)


        def always_err -> Task(Int, String)
          Task.fail("oops")


        def mapped -> Task(Int, String)
          map(Task.succeed(1), (n) -> { n + 1 })


        def chained -> Task(Int, String)
          and_then(Task.succeed(1), (n) -> { Task.succeed(n + 1) })


        def chained_err -> Task(Int, String)
          and_then(Task.succeed(1), (n) -> { Task.fail("chained error") })
      JADE
    end

    before { test_compiler.require('task_test', source) }

    it 'succeed produces an Ok on run' do
      expect(TaskTest.always_ok()).to be_task_ok(42)
    end

    it 'fail produces an Err on run' do
      expect(TaskTest.always_err()).to be_task_err('oops')
    end

    it 'wraps success as the literal outcome ["ok", encoded_value]' do
      expect(TaskTest.always_ok()).to eql ['ok', 42]
    end

    it 'wraps failure as the literal outcome ["err", encoded_err]' do
      expect(TaskTest.always_err()).to eql ['err', 'oops']
    end

    describe 'bang variant' do
      it 'returns the encoded ok value' do
        expect(TaskTest.always_ok!).to eql 42
      end

      it 'unwraps mapped/chained success' do
        expect(TaskTest.mapped!).to eql 2
        expect(TaskTest.chained!).to eql 2
      end

      it 'raises TaskError carrying the encoded err on failure' do
        expect { TaskTest.always_err! }
          .to raise_error(Jade::Interop::TaskError) { |e|
            expect(e.error).to eql 'oops'
          }
      end

      it 'raises TaskError on chained failure' do
        expect { TaskTest.chained_err! }
          .to raise_error(Jade::Interop::TaskError) { |e|
            expect(e.error).to eql 'chained error'
          }
      end
    end

    it 'map transforms the success value' do
      expect(TaskTest.mapped()).to be_task_ok(2)
    end

    it 'and_then chains tasks' do
      expect(TaskTest.chained()).to be_task_ok(2)
    end

    it 'and_then short-circuits on failure' do
      expect(TaskTest.chained_err()).to be_task_err('chained error')
    end

    context 'sequence' do
      let(:source) do
        <<~JADE
          module TaskTest exposing (all_ok, first_fails, second_fails)

          def all_ok -> Task(List(Int), String)
            Task.sequence([Task.succeed(1), Task.succeed(2), Task.succeed(3)])


          def first_fails -> Task(List(Int), String)
            Task.sequence(
              [Task.fail("first"), Task.succeed(2), Task.succeed(3)],
            )


          def second_fails -> Task(List(Int), String)
            Task.sequence(
              [Task.succeed(1), Task.fail("second"), Task.succeed(3)],
            )
        JADE
      end

      before { test_compiler.require('task_test', source) }

      it 'collects all values when all tasks succeed' do
        expect(TaskTest.all_ok()).to be_task_ok([1, 2, 3])
      end

      it 'short-circuits on the first failure' do
        expect(TaskTest.first_fails()).to be_task_err('first')
      end

      it 'short-circuits on any failure' do
        expect(TaskTest.second_fails()).to be_task_err('second')
      end

      it 'is lazy' do
        expect(TaskTest::Internal.all_ok).to be_a(Jade::Task)
      end
    end

    context 'on_error' do
      let(:source) do
        <<~JADE
          module TaskTest exposing (pass_through, recover, remap)

          def pass_through -> Task(Int, String)
            Task.on_error(Task.succeed(42), (e) -> { Task.succeed(0) })


          def recover -> Task(Int, String)
            Task.on_error(Task.fail("oops"), (e) -> { Task.succeed(0) })


          def remap -> Task(Int, String)
            Task.on_error(Task.fail("oops"), (e) -> { Task.fail(e ++ "!") })
        JADE
      end

      before { test_compiler.require('task_test', source) }

      it 'passes Ok through unchanged' do
        expect(TaskTest.pass_through()).to be_task_ok(42)
      end

      it 'recovers from a failed task' do
        expect(TaskTest.recover()).to be_task_ok(0)
      end

      it 'can remap the error' do
        expect(TaskTest.remap()).to be_task_err('oops!')
      end
    end

    context '<- syntax' do
      let(:source) do
        <<~JADE
          module TaskTest exposing (short_circuits, sum)

          def sum -> Task(Int, String)
            one <- Task.succeed(1)
            two <- Task.succeed(2)

            Task.succeed(one + two)


          def short_circuits -> Task(Int, String)
            one <- Task.fail("first error")
            two <- Task.succeed(2)

            Task.succeed(one + two)
        JADE
      end

      before { test_compiler.require('task_test', source) }

      it 'chains successful tasks' do
        expect(TaskTest.sum()).to be_task_ok(3)
      end

      it 'short-circuits on the first failure' do
        expect(TaskTest.short_circuits()).to be_task_err('first error')
      end

      it 'is lazy' do
        task = TaskTest::Internal.sum
        expect(task).to be_a(Jade::Task)
      end
    end

    context 'nothing runs until Task.run is called' do
      it 'succeed is lazy' do
        task = TaskTest::Internal.always_ok
        expect(task).to be_a(Jade::Task)
      end

      it 'map is lazy' do
        task = TaskTest::Internal.mapped
        expect(task).to be_a(Jade::Task)
      end

      it 'and_then is lazy' do
        task = TaskTest::Internal.chained
        expect(task).to be_a(Jade::Task)
      end
    end

    context 'Task fn with decodable args at the boundary' do
      let(:source) do
        <<~JADE
          module TaskTest exposing (echo, fail_with)

          def echo(n: Int, xs: List(String)) -> Task(String, String)
            Task.succeed(String.from_int(n) ++ ":" ++ String.concat(xs))


          def fail_with(reason: String) -> Task(Int, String)
            Task.fail(reason)
        JADE
      end

      before { test_compiler.require('task_test', source) }

      it 'decodes args, runs the Task, encodes the ok value' do
        expect(TaskTest.echo(7, ['a', 'b'])).to eql ['ok', '7:ab']
        expect(TaskTest.echo!(7, ['a', 'b'])).to eql '7:ab'
      end

      it 'decodes args, runs the Task, encodes the err value' do
        expect(TaskTest.fail_with('boom')).to eql ['err', 'boom']
        expect { TaskTest.fail_with!('boom') }
          .to raise_error(Jade::Interop::TaskError) { |e|
            expect(e.error).to eql 'boom'
          }
      end
    end
  end
end

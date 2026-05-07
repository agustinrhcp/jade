require 'spec_helper'

require 'jade'
require 'jade/module_loader'

module Jade
  describe 'Task' do
    include_context 'with test compiler'

    let(:source) do
      <<~JADE
        module TaskTest exposing (always_err, always_ok, chained, chained_err, mapped)

        def always_ok() -> Task(Int, String)
          Task.succeed(42)
        end

        def always_err() -> Task(Int, String)
          Task.fail("oops")
        end

        def mapped() -> Task(Int, String)
          map(Task.succeed(1), (n) -> { n + 1 })
        end

        def chained() -> Task(Int, String)
          and_then(Task.succeed(1), (n) -> { Task.succeed(n + 1) })
        end

        def chained_err() -> Task(Int, String)
          and_then(Task.succeed(1), (n) -> { Task.fail("chained error") })
        end
      JADE
    end

    before { test_compiler.require('task_test', source) }

    it 'succeed produces an Ok on run' do
      expect(TaskTest.always_ok.call.run).to be_ok(42)
    end

    it 'fail produces an Err on run' do
      expect(TaskTest.always_err.call.run).to be_err('oops')
    end

    it 'map transforms the success value' do
      expect(TaskTest.mapped.call.run).to be_ok(2)
    end

    it 'and_then chains tasks' do
      expect(TaskTest.chained.call.run).to be_ok(2)
    end

    it 'and_then short-circuits on failure' do
      expect(TaskTest.chained_err.call.run).to be_err('chained error')
    end

    context 'sequence' do
      let(:source) do
        <<~JADE
          module TaskTest exposing (all_ok, first_fails, second_fails)

          def all_ok() -> Task(List(Int), String)
            Task.sequence([Task.succeed(1), Task.succeed(2), Task.succeed(3)])
          end

          def first_fails() -> Task(List(Int), String)
            Task.sequence([Task.fail("first"), Task.succeed(2), Task.succeed(3)])
          end

          def second_fails() -> Task(List(Int), String)
            Task.sequence([Task.succeed(1), Task.fail("second"), Task.succeed(3)])
          end
        JADE
      end

      before { test_compiler.require('task_test', source) }

      it 'collects all values when all tasks succeed' do
        expect(TaskTest.all_ok.call.run).to be_ok([1, 2, 3])
      end

      it 'short-circuits on the first failure' do
        expect(TaskTest.first_fails.call.run).to be_err('first')
      end

      it 'short-circuits on any failure' do
        expect(TaskTest.second_fails.call.run).to be_err('second')
      end

      it 'is lazy' do
        expect(TaskTest.all_ok.call).to be_a(Jade::Task)
      end
    end

    context 'on_error' do
      let(:source) do
        <<~JADE
          module TaskTest exposing (pass_through, recover, remap)

          def pass_through() -> Task(Int, String)
            Task.on_error(Task.succeed(42), (e) -> { Task.succeed(0) })
          end

          def recover() -> Task(Int, String)
            Task.on_error(Task.fail("oops"), (e) -> { Task.succeed(0) })
          end

          def remap() -> Task(Int, String)
            Task.on_error(Task.fail("oops"), (e) -> { Task.fail(e ++ "!") })
          end
        JADE
      end

      before { test_compiler.require('task_test', source) }

      it 'passes Ok through unchanged' do
        expect(TaskTest.pass_through.call.run).to be_ok(42)
      end

      it 'recovers from a failed task' do
        expect(TaskTest.recover.call.run).to be_ok(0)
      end

      it 'can remap the error' do
        expect(TaskTest.remap.call.run).to be_err('oops!')
      end
    end

    context '<- syntax' do
      let(:source) do
        <<~JADE
          module TaskTest exposing (short_circuits, sum)

          def sum() -> Task(Int, String)
            one <- Task.succeed(1)
            two <- Task.succeed(2)

            Task.succeed(one + two)
          end

          def short_circuits() -> Task(Int, String)
            one <- Task.fail("first error")
            two <- Task.succeed(2)

            Task.succeed(one + two)
          end
        JADE
      end

      before { test_compiler.require('task_test', source) }

      it 'chains successful tasks' do
        expect(TaskTest.sum.call.run).to be_ok(3)
      end

      it 'short-circuits on the first failure' do
        expect(TaskTest.short_circuits.call.run).to be_err('first error')
      end

      it 'is lazy' do
        task = TaskTest.sum.call
        expect(task).to be_a(Jade::Task)
      end
    end

    context 'nothing runs until Task.run is called' do
      it 'succeed is lazy' do
        task = TaskTest.always_ok.call
        expect(task).to be_a(Jade::Task)
      end

      it 'map is lazy' do
        task = TaskTest.mapped.call
        expect(task).to be_a(Jade::Task)
      end

      it 'and_then is lazy' do
        task = TaskTest.chained.call
        expect(task).to be_a(Jade::Task)
      end
    end
  end
end

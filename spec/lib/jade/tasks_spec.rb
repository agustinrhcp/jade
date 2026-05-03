require 'spec_helper'

require 'jade/tasks'
require 'jade/tasks/rspec'

module Jade
  describe Tasks do
    include Jade::Tasks::RSpec

    let(:user_create)  { TaskDef.new('User', 'Create') }
    let(:user_welcome) { TaskDef.new('User', 'SendWelcome') }

    describe 'dispatch' do
      it 'calls the block with the helper and dispatched args' do
        captured = nil
        next_call_to(user_create) { |t, email, pw| captured = [email, pw]; t.ok(nil) }

        Tasks.dispatch(user_create, 'a@b.com', 'pw')

        expect(captured).to eq(['a@b.com', 'pw'])
      end

      it 'returns whatever the block produced' do
        next_call_to(user_create) { |t, email| t.ok(email.upcase) }

        expect(Tasks.dispatch(user_create, 'a')).to eq(Jade::Result::Ok['A'])
      end

      it 'raises Unbound when the task has no stub' do
        expect { Tasks.dispatch(user_create, 'a') }
          .to raise_error(Tasks::Unbound, /No stub for User\.Create.*"a"/)
      end

      it 'raises ReturnedTask when the block returns a Jade::Task' do
        next_call_to(user_create) { |_t, _| Jade::Task::Literal.new(Jade::Result::Ok[1]) }

        expect { Tasks.dispatch(user_create, 'a') }
          .to raise_error(Tasks::ReturnedTask, /tasks must not return tasks/)
      end

      it 'one next_call_to(task, value) is one-shot — second call raises in strict mode' do
        next_call_to(user_create, 'once')

        expect(Tasks.dispatch(user_create, '_')).to eq(Jade::Result::Ok['once'])
        expect { Tasks.dispatch(user_create, '_') }.to raise_error(Tasks::Unbound)
      end

      it 'multiple next_call_to calls queue answers consumed in order' do
        next_call_to(user_create, 'first')
        next_call_to(user_create, 'second')
        next_call_to(user_create, 'third')

        expect(Tasks.dispatch(user_create, '_')).to eq(Jade::Result::Ok['first'])
        expect(Tasks.dispatch(user_create, '_')).to eq(Jade::Result::Ok['second'])
        expect(Tasks.dispatch(user_create, '_')).to eq(Jade::Result::Ok['third'])
      end

      it 'all_calls_to(task, value) applies to every call' do
        all_calls_to(user_create, 5)

        expect(Tasks.dispatch(user_create, '_')).to eq(Jade::Result::Ok[5])
        expect(Tasks.dispatch(user_create, '_')).to eq(Jade::Result::Ok[5])
        expect(Tasks.dispatch(user_create, '_')).to eq(Jade::Result::Ok[5])
      end

      it 'all_calls_to with a block runs the block on every call' do
        all_calls_to(user_create) { |t, n| t.ok(n * 2) }

        expect(Tasks.dispatch(user_create, 3)).to eq(Jade::Result::Ok[6])
        expect(Tasks.dispatch(user_create, 4)).to eq(Jade::Result::Ok[8])
      end

      it 'next_call_to is consumed first; all_calls_to is the fallback when the queue drains' do
        next_call_to(user_create, 1)
        next_call_to(user_create, 2)
        all_calls_to(user_create, 0)

        expect(Tasks.dispatch(user_create, '_')).to eq(Jade::Result::Ok[1])
        expect(Tasks.dispatch(user_create, '_')).to eq(Jade::Result::Ok[2])
        expect(Tasks.dispatch(user_create, '_')).to eq(Jade::Result::Ok[0])
        expect(Tasks.dispatch(user_create, '_')).to eq(Jade::Result::Ok[0])
      end
    end

    describe 'have_been_called matcher' do
      before do
        all_calls_to(user_create)  { |t, *| t.ok(nil) }
        all_calls_to(user_welcome) { |t, *| t.ok(nil) }
      end

      it 'passes when the task was called at least once' do
        Tasks.dispatch(user_create, 'a')

        expect(user_create).to have_been_called
      end

      it 'negated form passes cleanly when the task was never called' do
        expect(user_welcome).not_to have_been_called
      end

      it 'matches on args via .with' do
        Tasks.dispatch(user_create, 'a@b.com', 'pw')

        expect(user_create).to have_been_called.with('a@b.com', 'pw')
        expect(user_create).not_to have_been_called.with('other', 'pw')
      end

      it 'counts calls via .times' do
        Tasks.dispatch(user_create, 'a')
        Tasks.dispatch(user_create, 'b')

        expect(user_create).to have_been_called.times(2)
      end

      it 'shorthand .once' do
        Tasks.dispatch(user_create, 'a')

        expect(user_create).to have_been_called.once
      end
    end

    describe 'isolation between examples' do
      it 'does not see calls from a sibling example' do
        expect(user_create).not_to have_been_called
      end

      it 'sibling example to prove leakage would be visible' do
        all_calls_to(user_create) { |t, *| t.ok(nil) }
        Tasks.dispatch(user_create, 'leak')

        expect(user_create).to have_been_called.with('leak')
      end

      it 'does not see stubs from a sibling example' do
        expect { Tasks.dispatch(user_create, 'a') }
          .to raise_error(Tasks::Unbound)
      end
    end
  end
end

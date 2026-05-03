require 'spec_helper'

require 'jade/tasks'
require 'jade/tasks/rspec'

module Jade
  describe Tasks do
    include Jade::Tasks::RSpec

    let(:user_create)  { TaskDef.new('User', 'Create') }
    let(:user_welcome) { TaskDef.new('User', 'SendWelcome') }

    describe 'dispatch' do
      it 'calls the stub block with the dispatched args (helper t is yielded first)' do
        captured = nil
        stub_task(user_create) { |t, email, pw| captured = [email, pw]; t.ok }

        Tasks.dispatch(user_create, 'a@b.com', 'pw')

        expect(captured).to eq(['a@b.com', 'pw'])
      end

      it 'returns whatever the stub produced (Outcome.ok wraps in Result::Ok)' do
        stub_task(user_create) { |t, email| t.ok(email.upcase) }

        expect(Tasks.dispatch(user_create, 'a')).to eq(::Result::Ok['A'])
      end

      it 'raises Unbound when the task has no stub' do
        expect { Tasks.dispatch(user_create, 'a') }
          .to raise_error(Tasks::Unbound, /No stub for User\.Create.*"a"/)
      end

      it 'raises ReturnedTask when the stub returns a Jade::Task' do
        stub_task(user_create) { |_t, _| Jade::Task.ok { 1 } }

        expect { Tasks.dispatch(user_create, 'a') }
          .to raise_error(Tasks::ReturnedTask, /tasks must not return tasks/)
      end
    end

    describe 'have_been_called matcher' do
      before { stub_task(user_create)  { |t, *| t.ok } }
      before { stub_task(user_welcome) { |t, *| t.ok } }

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
        # The sibling below dispatches user_create — we should NOT see it here.
        expect(user_create).not_to have_been_called
      end

      it 'sibling example to prove leakage would be visible' do
        stub_task(user_create) { |t, *| t.ok }
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

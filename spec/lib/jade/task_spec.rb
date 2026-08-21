require 'spec_helper'

require 'jade'
require 'jade/tasks'
require 'jade/task'

module Jade
  describe Task do
    include_context "with test compiler"

    # Jade::Result is defined by the emitted stdlib rather than by the library,
    # so a compiled module has to be loaded before Task can speak it.
    before { test_compiler.require("module Seed exposing (n)\n\ndef n -> Int\n  1\nend\n") }

    def ok(value)
      Task::Literal[Jade::Result::Ok[value]]
    end

    def err(error)
      Task::Literal[Jade::Result::Err[error]]
    end

    describe 'composition' do
      it 'threads a value through and_then' do
        task = Task::AndThen[ok(1), ->(n) { ok(n + 1) }]

        expect(task.run).to eq Jade::Result::Ok[2]
      end

      it 'skips the rest of a chain once it fails' do
        reached = false
        task = Task::AndThen[err(:boom), ->(_) { reached = true; ok(1) }]

        expect(task.run).to eq Jade::Result::Err[:boom]
        expect(reached).to be false
      end

      it 'maps only the ok arm' do
        expect(Task::Map[ok(2), ->(n) { n * 3 }].run).to eq Jade::Result::Ok[6]
        expect(Task::Map[err(:boom), ->(_) { 0 }].run).to eq Jade::Result::Err[:boom]
      end

      it 'maps only the error arm' do
        expect(Task::MapError[err(:boom), ->(e) { [e] }].run).to eq Jade::Result::Err[[:boom]]
        expect(Task::MapError[ok(1), ->(_) { :nope }].run).to eq Jade::Result::Ok[1]
      end

      it 'recovers through on_error' do
        task = Task::OnError[err(:boom), ->(_) { ok(:recovered) }]

        expect(task.run).to eq Jade::Result::Ok[:recovered]
      end

      it 'leaves a successful task alone through on_error' do
        reached = false
        task = Task::OnError[ok(1), ->(_) { reached = true; ok(2) }]

        expect(task.run).to eq Jade::Result::Ok[1]
        expect(reached).to be false
      end

      it 'resumes the chain after recovering' do
        task = Task::AndThen[
          Task::OnError[err(:boom), ->(_) { ok(1) }],
          ->(n) { ok(n + 1) },
        ]

        expect(task.run).to eq Jade::Result::Ok[2]
      end
    end

    # `run` drives an explicit stack rather than calling itself, so the depth a
    # chain can reach is bounded by memory instead of by the Ruby stack. A batch
    # loop built out of and_then is the reason this matters.
    describe 'a deeply nested chain' do
      def chain(depth)
        (1..depth).reduce(ok(0)) do |task, _|
          Task::AndThen[task, ->(n) { ok(n + 1) }]
        end
      end

      it 'runs without exhausting the stack' do
        expect(chain(100_000).run).to eq Jade::Result::Ok[100_000]
      end

      it 'carries a failure out of the middle of one' do
        task = Task::AndThen[chain(50_000), ->(_) { err(:boom) }]

        expect(Task::AndThen[task, ->(_) { ok(:unreachable) }].run)
          .to eq Jade::Result::Err[:boom]
      end
    end
  end
end

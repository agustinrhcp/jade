require 'spec_helper'
require 'date'

require 'jade'
require 'jade/module_loader'
require 'jade/tasks'
require 'jade/tasks/rspec'

# Auto-registration: `task :name` creates a stable TaskDef and exposes it as
# `DateTasks.today`. The block uses the yielded helper `t` for `t.ok` / `t.err`,
# so no name pollution on the module itself.
module DateTasks
  extend Jade::Tasks::Module

  def self.to_int(date)
    date.year * 10000 + date.month * 100 + date.day
  end

  task :today do |t|
    t.ok(to_int(::Date.today))
  end

  task :plus_days do |t, n|
    t.ok(to_int(::Date.today + n))
  end
end

# Sample Jade-shaped values for matchers — these mirror what the codegen emits
# for `type Maybe(a) = Just(a) | Nothing` and `struct Point { x, y }`.
module Maybe
  Just    = Data.define(:_1) unless const_defined?(:Just, false)
  Nothing = Data.define      unless const_defined?(:Nothing, false)
end

module Geometry
  Point = Data.define(:x, :y) unless const_defined?(:Point, false)
end

describe 'tasks mocker — DateTasks example' do
  include_context 'with test compiler'
  include Jade::Tasks::RSpec

  let(:schedule_source) do
    <<~JADE
      module Schedule exposing(run)

      uses DateTasks with
        today: Task(Int, Never),
        plus_days: Int -> Task(Int, Never)
      end

      def run(offset: Int) -> Task(Int, Never)
        _ <- today()
        plus_days(offset)
      end
    JADE
  end

  before { test_compiler.require('schedule', schedule_source) }

  describe 'auto-registration via the DSL' do
    it 'exposes a TaskDef accessor on the module' do
      expect(DateTasks.today).to be_a(Jade::TaskDef)
      expect(DateTasks.today.name).to eq('today')
      expect(DateTasks.today.module_name).to eq('DateTasks')
    end

    it 'returns the same TaskDef on every call (stable identity)' do
      expect(DateTasks.today).to equal(DateTasks.today)
    end
  end

  describe 'stubbing tasks called from compiled Jade source' do
    before do
      stub_task(DateTasks.today)     { |t|    t.ok(20260101) }
      stub_task(DateTasks.plus_days) { |t, n| t.ok(20260101 + n) }
    end

    it 'runs the chain against stubs, no real Date.today touched' do
      expect(Schedule.run.call(2).run).to eq(Result::Ok[20260103])

      expect(DateTasks.today).to have_been_called
      expect(DateTasks.plus_days).to have_been_called.with(2)
    end

    it 'short-circuits when the first task fails' do
      stub_task(DateTasks.today) { |t| t.err(:no_clock) }

      expect(Schedule.run.call(2).run).to eq(Result::Err[:no_clock])

      expect(DateTasks.today).to have_been_called
      expect(DateTasks.plus_days).not_to have_been_called
    end
  end

  describe 'forgetting to stub' do
    it 'raises rather than calling the real registered body — strict mode' do
      expect { Schedule.run.call(0).run }
        .to raise_error(Jade::Tasks::Unbound, /DateTasks\.today/)
    end
  end
end

describe 'jade-value matchers' do
  describe 'match_jade_union' do
    it 'matches a constructor with positional args' do
      expect(Maybe::Just[5]).to match_jade_union(Maybe::Just, 5)
    end

    it 'matches a no-arg constructor' do
      expect(Maybe::Nothing.new).to match_jade_union(Maybe::Nothing)
    end

    it 'fails when the constructor class differs' do
      expect(Maybe::Just[5]).not_to match_jade_union(Maybe::Nothing)
    end

    it 'fails when the args differ' do
      expect(Maybe::Just[5]).not_to match_jade_union(Maybe::Just, 6)
    end
  end

  describe 'match_jade_struct' do
    it 'matches by class and field values' do
      expect(Geometry::Point.new(x: 1, y: 2)).to match_jade_struct(Geometry::Point, x: 1, y: 2)
    end

    it 'fails when the field values differ' do
      expect(Geometry::Point.new(x: 1, y: 2)).not_to match_jade_struct(Geometry::Point, x: 1, y: 3)
    end
  end
end

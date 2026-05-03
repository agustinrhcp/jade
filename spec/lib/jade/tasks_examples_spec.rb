require 'spec_helper'
require 'date'

require 'jade'
require 'jade/module_loader'
require 'jade/tasks'
require 'jade/tasks/rspec'

module DateTasks
  extend Jade::Port

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

# Unique short names so symbol-form lookup is unambiguous against the
# stdlib's Jade::Maybe::Just / Jade::Maybe::Nothing.
module SpecMaybe
  SpecJust    = Data.define(:_1)
  SpecNothing = Data.define
end

module Geometry
  Point = Data.define(:x, :y)
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
      all_calls_to(DateTasks.today)     { |t|    t.ok(20260101) }
      all_calls_to(DateTasks.plus_days) { |t, n| t.ok(20260101 + n) }
    end

    it 'runs the chain against stubs, no real Date.today touched' do
      expect(Schedule.run.call(2).run).to be_ok(20260103)

      expect(DateTasks.today).to have_been_called
      expect(DateTasks.plus_days).to have_been_called.with(2)
    end

    it 'short-circuits when the first task fails' do
      all_calls_to(DateTasks.today) { |t| t.err(:no_clock) }

      expect(Schedule.run.call(2).run).to be_err(:no_clock)

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

describe 'look_like matcher' do
  describe 'symbol form (short name lookup)' do
    it 'matches a constructor with positional args' do
      expect(SpecMaybe::SpecJust[5]).to look_like(:SpecJust, 5)
    end

    it 'matches a no-arg constructor' do
      expect(SpecMaybe::SpecNothing.new).to look_like(:SpecNothing)
    end

    it 'matches struct fields via kwargs (class form when short name is ambiguous)' do
      expect(Geometry::Point.new(x: 1, y: 2)).to look_like(Geometry::Point, x: 1, y: 2)
    end

    it 'raises a helpful error when the short name is ambiguous' do
      stub_const('AnotherModule::Point', Data.define(:x, :y))

      expect { look_like(:Point, x: 1, y: 2).matches?(Geometry::Point.new(x: 1, y: 2)) }
        .to raise_error(/Ambiguous :Point/)
    end

    it 'fails when the constructor differs' do
      expect(SpecMaybe::SpecJust[5]).not_to look_like(:SpecNothing)
    end

    it 'fails when args differ' do
      expect(SpecMaybe::SpecJust[5]).not_to look_like(:SpecJust, 6)
    end
  end

  describe 'class form' do
    it 'accepts the class constant directly' do
      expect(SpecMaybe::SpecJust[5]).to look_like(SpecMaybe::SpecJust, 5)
    end
  end

  describe 'string form (qualified name)' do
    it 'resolves Module::Name' do
      expect(SpecMaybe::SpecJust[5]).to look_like('SpecMaybe::SpecJust', 5)
    end
  end

  describe 'nesting via arrays' do
    # Nested Just(Just(5))
    it 'matches a constructor wrapped in another constructor' do
      expect(SpecMaybe::SpecJust[SpecMaybe::SpecJust[5]]).to look_like(:SpecJust, [:SpecJust, 5])
    end

    it 'mixes nested constructors and plain literals (class form when short name is ambiguous)' do
      pair_class   = Data.define(:_1, :_2)
      circle_class = Data.define(:_1)

      pair = pair_class[circle_class[5.0], 42]

      expect(pair).to look_like(pair_class, [circle_class, 5.0], 42)
    end
  end

  describe 'composing with RSpec matchers via ===' do
    it 'accepts anything as a wildcard' do
      expect(SpecMaybe::SpecJust[5]).to look_like(:SpecJust, anything)
    end

    it 'accepts kind_of for type-only checks' do
      expect(SpecMaybe::SpecJust[5]).to look_like(:SpecJust, kind_of(Integer))
    end

    it 'accepts a Range' do
      expect(SpecMaybe::SpecJust[5]).to look_like(:SpecJust, 1..10)
    end
  end
end

describe 'be_ok / be_err convenience matchers' do
  it 'be_ok with no args matches any Ok' do
    expect(Jade::Result::Ok[42]).to be_ok
    expect(Jade::Result::Ok['anything']).to be_ok
    expect(Jade::Result::Err['oops']).not_to be_ok
  end

  it 'be_ok(value) matches the inner value' do
    expect(Jade::Result::Ok[42]).to be_ok(42)
    expect(Jade::Result::Ok[42]).not_to be_ok(43)
  end

  it 'be_ok composes with other matchers' do
    expect(Jade::Result::Ok[42]).to be_ok(kind_of(Integer))
    expect(Jade::Result::Ok[42]).to be_ok(anything)
  end

  it 'be_err with no args matches any Err' do
    expect(Jade::Result::Err[:nope]).to be_err
    expect(Jade::Result::Ok[42]).not_to be_err
  end

  it 'be_err(value) matches the inner error' do
    expect(Jade::Result::Err[:no_clock]).to be_err(:no_clock)
    expect(Jade::Result::Err[:no_clock]).not_to be_err(:other)
  end

  it 'be_just / be_nothing for Maybe' do
    expect(Jade::Maybe::Just[5]).to be_just
    expect(Jade::Maybe::Just[5]).to be_just(5)
    expect(Jade::Maybe::Nothing[]).to be_nothing
    expect(Jade::Maybe::Just[5]).not_to be_nothing
  end
end

describe 'auto-generated predicates for user-defined unions' do
  include_context 'with test compiler'

  before do
    test_compiler.require('shapes', <<~JADE)
      module Shapes exposing(Shape(..))

      type Shape = Circle(Float) | Rectangle(Float, Float)
    JADE
  end

  it 'each variant gets a sibling-aware predicate' do
    circle    = Shapes::Circle[5.0]
    rectangle = Shapes::Rectangle[3.0, 4.0]

    expect(circle).to be_circle
    expect(circle).not_to be_rectangle
    expect(rectangle).to be_rectangle
    expect(rectangle).not_to be_circle
  end
end

describe 'snake_case predicate names for multi-word variants' do
  include_context 'with test compiler'

  before do
    test_compiler.require('events', <<~JADE)
      module Events exposing(Event(..))

      type Event = UserSignedUp(String) | OrderPlaced(Int)
    JADE
  end

  it 'emits snake_case predicates for CamelCase variant names' do
    expect(Events::UserSignedUp['a@b.com']).to be_user_signed_up
    expect(Events::UserSignedUp['a@b.com']).not_to be_order_placed
    expect(Events::OrderPlaced[42]).to be_order_placed
    expect(Events::OrderPlaced[42]).not_to be_user_signed_up
  end
end

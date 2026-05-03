require 'rspec/expectations'

require 'jade/tasks'

module Jade
  module Tasks
    module RSpec
      def stub_task(task_def, &block)
        Jade::Tasks.stub(task_def, &block)
      end

      def self.included(base)
        base.before(:each) { Jade::Tasks.reset!(strict: true) }
      end
    end
  end
end

::RSpec::Matchers.define :match_jade_union do |klass, *args|
  match do |actual|
    @actual = actual
    actual.is_a?(klass) && actual.deconstruct == args
  end

  failure_message do
    "expected #{@actual.inspect} to be #{klass}(#{args.map(&:inspect).join(', ')})"
  end
end

::RSpec::Matchers.define :match_jade_struct do |klass, **fields|
  match do |actual|
    @actual = actual
    actual.is_a?(klass) && actual.deconstruct_keys(fields.keys) == fields
  end

  failure_message do
    expected = fields.map { |k, v| "#{k}: #{v.inspect}" }.join(', ')
    "expected #{@actual.inspect} to be #{klass}(#{expected})"
  end
end

::RSpec::Matchers.define :have_been_called do
  match do |task_def|
    @task_def = task_def
    @actual = Jade::Tasks.calls_to(task_def)
    matches = @args ? @actual.select { |a| a == @args } : @actual
    @count ? matches.length == @count : matches.any?
  end

  match_when_negated do |task_def|
    @task_def = task_def
    @actual = Jade::Tasks.calls_to(task_def)
    matches = @args ? @actual.select { |a| a == @args } : @actual
    matches.empty?
  end

  chain :with do |*args|
    @args = args
  end

  chain :times do |count|
    @count = count
  end

  chain :once do
    @count = 1
  end

  failure_message do
    suffix = @args ? " with #{@args.inspect}" : ""
    suffix += " #{@count} time(s)" if @count
    "expected #{@task_def} to have been called#{suffix}, but calls were #{@actual.inspect}"
  end

  failure_message_when_negated do
    suffix = @args ? " with #{@args.inspect}" : ""
    "expected #{@task_def} not to have been called#{suffix}, but calls were #{@actual.inspect}"
  end
end

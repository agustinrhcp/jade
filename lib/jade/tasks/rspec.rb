require 'rspec/expectations'

require 'jade/tasks'

module Jade
  module Tasks
    Block = Data.define(:block)

    class TestRegistry
      attr_accessor :strict

      def initialize
        @persistent = {}
        @queues     = Hash.new { |h, k| h[k] = [] }
        @calls      = Hash.new { |h, k| h[k] = [] }
        @strict     = false
      end

      def queue_next(task_def, answer)
        @queues[task_def] << answer
      end

      def set_persistent(task_def, answer)
        @persistent[task_def] = answer
      end

      def dispatch(task_def, args)
        @calls[task_def] << args

        pick_answer(task_def)
          .then { it || fail(Unbound.new(task_def, args, @strict)) }
          .then { resolve(it, args) }
          .tap { |value| fail ReturnedTask.new(task_def) if value.is_a?(Jade::Task) }
      end

      def calls_to(task_def)
        @calls[task_def]
      end

      private

      def pick_answer(task_def)
        @queues[task_def].shift ||
          @persistent[task_def] ||
          (@strict ? nil : REGISTRATIONS[task_def]&.then { Block.new(it) })
      end

      def resolve(answer, args)
        case answer
        in Block(block) then block.call(Outcome, *args)
        else Jade::Result::Ok[answer]
        end
      end
    end

    # Override production dispatch to route through the per-thread test registry.
    def self.dispatch(task_def, *args)
      test_registry.dispatch(task_def, args)
    end

    def self.test_registry
      Thread.current[:jade_tasks_test_registry] ||= TestRegistry.new
    end

    def self.reset!(strict: false)
      Thread.current[:jade_tasks_test_registry] = TestRegistry
        .new
        .tap { it.strict = strict }
    end

    # Test-mode Unbound carries an extra `strict` field for a more helpful
    # message when a test forgot to stub.
    remove_const(:Unbound)

    class Unbound < StandardError
      def initialize(task_def, args, strict)
        kind = strict ? 'stub' : 'stub or registration'
        super("No #{kind} for #{task_def}; called with #{args.inspect}")
      end
    end

    module RSpec
      def next_call_to(task_def, value = OMITTED, &block)
        Jade::Tasks
          .test_registry
          .queue_next(task_def, answer_for(value, block))
      end

      def all_calls_to(task_def, value = OMITTED, &block)
        Jade::Tasks
          .test_registry
          .set_persistent(task_def, answer_for(value, block))
      end

      OMITTED = Object.new.freeze
      private_constant :OMITTED

      private

      def answer_for(value, block)
        if block
          Jade::Tasks::Block.new(block)
        elsif value.equal?(OMITTED)
          fail ArgumentError, "needs a value or a block"
        else
          value
        end
      end

      def self.included(base)
        base.before(:each) { Jade::Tasks.reset!(strict: true) }
      end

      module Loose
        def self.included(base)
          base.include(Jade::Tasks::RSpec)
          base.before(:each) { Jade::Tasks.reset!(strict: false) }
        end
      end
    end

    module Matcher
      extend self

      def resolve(name)
        case name
        when ::Class, ::Module
          name
        when ::String
          Object.const_get(name)
        when ::Symbol
          full_names = lookup_short_name(name.to_s).map(&:name).uniq
          case full_names.length
          when 1 then Object.const_get(full_names.first)
          when 0
            fail "No constant named #{name.inspect}; " \
              "pass the class itself or a 'Module::Name' string"
          else
            fail "Ambiguous #{name.inspect}: #{full_names.join(', ')}; " \
              "use the qualified 'Module::Name' string"
          end
        end
      end

      def match?(actual, name, positional, named)
        klass = resolve(name)
        return false unless actual.is_a?(klass)

        if named.any?
          return false if positional.any?

          actual_kw = actual.deconstruct_keys(named.keys)
          named.all? { |k, expected| arg_match?(actual_kw[k], expected) }
        else
          actual_args = actual.respond_to?(:deconstruct) ? actual.deconstruct : []
          return false unless actual_args.length == positional.length

          actual_args.zip(positional).all? { |a, e| arg_match?(a, e) }
        end
      end

      def arg_match?(actual, expected)
        return expected === actual || expected == actual unless expected.is_a?(::Array)

        case expected
        in [::Symbol | ::String | ::Module => name, *positional, ::Hash => named]
          match?(actual, name, positional, named)

        in [::Symbol | ::String | ::Module => name, *positional]
          match?(actual, name, positional, {})

        else
          expected == actual
        end
      end

      private

      def lookup_short_name(short)
        matches = ->(m) {
          Module
            .instance_method(:name)
            .bind(m).call
            .then { it && it.split('::').last == short }
        }

        ObjectSpace.each_object(Class).select(&matches) +
          ObjectSpace.each_object(Module).select { |m| !m.is_a?(Class) && matches.call(m) }
      end
    end
  end
end

::RSpec::Matchers.define :have_been_called do
  def matching_calls(task_def)
    actual = Jade::Tasks.test_registry.calls_to(task_def)
    @args ? actual.select { |a| a == @args } : actual
  end

  match do |task_def|
    @task_def = task_def
    @actual   = Jade::Tasks.test_registry.calls_to(task_def)
    matches   = matching_calls(task_def)
    @count ? matches.length == @count : matches.any?
  end

  match_when_negated do |task_def|
    @task_def = task_def
    @actual   = Jade::Tasks.test_registry.calls_to(task_def)
    matching_calls(task_def).empty?
  end

  chain(:with)   { |*args| @args = args }
  chain(:times)  { |count| @count = count }
  chain(:once)   { @count = 1 }

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

::RSpec::Matchers.define :look_like do |name, *positional, **named|
  match do |actual|
    @actual = actual
    Jade::Tasks::Matcher.match?(actual, name, positional, named)
  end

  failure_message do
    args = (positional.map(&:inspect) + named.map { |k, v| "#{k}: #{v.inspect}" }).join(', ')
    "expected #{@actual.inspect} to look like #{name}(#{args})"
  end
end

{
  ok:      'Jade::Result::Ok',
  err:     'Jade::Result::Err',
  just:    'Jade::Maybe::Just',
  nothing: 'Jade::Maybe::Nothing',
}.each do |kind, full_name|
  ::RSpec::Matchers.define :"be_#{kind}" do |*args, **named|
    match do |actual|
      @actual = actual
      if args.empty? && named.empty?
        actual.respond_to?(:"#{kind}?") && actual.public_send(:"#{kind}?")
      else
        Jade::Tasks::Matcher.match?(actual, full_name, args, named)
      end
    end

    failure_message do
      if args.empty? && named.empty?
        "expected #{@actual.inspect} to respond truthy to .#{kind}?"
      else
        inner = (args.map(&:inspect) + named.map { |k, v| "#{k}: #{v.inspect}" }).join(', ')
        "expected #{@actual.inspect} to be #{kind.to_s.capitalize}(#{inner})"
      end
    end
  end
end

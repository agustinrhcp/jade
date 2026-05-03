module Jade
  module Task; end  # forward declaration; variants defined in jade/task

  TaskDef = Data.define(:module_name, :name) do
    def to_s    = "#{module_name}.#{name}"
    def inspect = "#<TaskDef #{self}>"
  end

  module Tasks
    extend self

    REGISTRATIONS = {}

    class Unbound < StandardError
      def initialize(task_def, args, strict)
        kind = strict ? 'stub' : 'stub or registration'
        super("No #{kind} for #{task_def}; called with #{args.inspect}")
      end
    end

    class ReturnedTask < StandardError
      def initialize(task_def)
        super("Body of #{task_def} returned a Jade::Task — tasks must not return tasks; compose with map/and_then/sequence in Jade instead")
      end
    end

    class Registry
      attr_accessor :strict

      def initialize
        @stubs  = {}
        @calls  = Hash.new { |h, k| h[k] = [] }
        @strict = false
      end

      def stub(task_def, &block)
        @stubs[task_def] = block
      end

      def dispatch(task_def, args)
        @calls[task_def] << args

        block = @stubs[task_def]
        block ||= REGISTRATIONS[task_def] unless @strict
        fail Unbound.new(task_def, args, @strict) unless block

        block.call(Outcome, *args).tap do |value|
          fail ReturnedTask.new(task_def) if value.is_a?(Jade::Task)
        end
      end

      def calls_to(task_def) = @calls[task_def]
    end

    def registry
      Thread.current[:jade_tasks_registry] ||= Registry.new
    end

    def reset!(strict: false)
      Thread.current[:jade_tasks_registry] = Registry.new.tap { it.strict = strict }
    end

    def register(task_def, &block) = REGISTRATIONS[task_def] = block

    def stub(task_def, &block)     = registry.stub(task_def, &block)
    def dispatch(task_def, *args)  = registry.dispatch(task_def, args)
    def calls_to(task_def)         = registry.calls_to(task_def)

    module Outcome
      extend self
      def ok(value = nil)  = ::Result::Ok[value]
      def err(error = nil) = ::Result::Err[error]
    end

    module Module
      def task(name, &block)
        Jade::TaskDef
          .new(self.name, name.to_s)
          .tap { Jade::Tasks.register(it, &block) }
          .tap { |task_def| define_singleton_method(name) { task_def } }
      end
    end
  end
end

require 'jade/task'

module Jade
  module Task; end

  TaskDef = Data.define(:module_name, :name) do
    def to_s
      "#{module_name}.#{name}"
    end

    def inspect
      "#<TaskDef #{self}>"
    end
  end

  module Port
    def task(name, &block)
      Jade::TaskDef
        .new(self.name, name.to_s)
        .tap { Jade::Tasks.register(it, &block) }
        .tap { |task_def| define_singleton_method(name) { task_def } }
    end
  end

  module Tasks
    extend self

    REGISTRATIONS = {}

    class Unbound < StandardError
      def initialize(task_def, args)
        super("No port registered for #{task_def}; called with #{args.inspect}")
      end
    end

    class ReturnedTask < StandardError
      def initialize(task_def)
        super(
          "Body of #{task_def} returned a Jade::Task — tasks must not return tasks; " \
            "compose with map/and_then/sequence in Jade instead"
        )
      end
    end

    def register(task_def, &block)
      REGISTRATIONS[task_def] = block
    end

    def dispatch(task_def, *args)
      block = REGISTRATIONS[task_def]
      fail Unbound.new(task_def, args) unless block

      block.call(Outcome, *args).tap do |value|
        fail ReturnedTask.new(task_def) if value.is_a?(Jade::Task)
      end
    end

    module Outcome
      extend self

      def ok(value)
        Jade::Result::Ok[value]
      end

      def err(error)
        Jade::Result::Err[error]
      end
    end
  end
end

require 'jade/task'

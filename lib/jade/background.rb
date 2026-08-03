module Jade
  # Where backgrounded tasks go. An adapter receives a port name and its
  # already-encoded arguments, and is responsible for getting them to a
  # worker that can call Jade::Tasks.dispatch with them again.
  module Background
    extend self

    class NoAdapter < StandardError
      def initialize
        super(
          'No background adapter configured. Set Jade::Background.adapter to ' \
            'something responding to #enqueue(module_name, name, args).'
        )
      end
    end

    # Runs the task immediately, in this process. The default because a
    # test suite should not need Redis, and because it makes the failure
    # mode of an unconfigured app obvious rather than silent.
    module Inline
      extend self

      def enqueue(task_def, args)
        Jade::Tasks.dispatch(task_def, *args)
        "inline:#{task_def}"
      end
    end

    attr_writer :adapter

    def adapter
      @adapter ||= Inline
    end

    def enqueue(task_def, args)
      fail NoAdapter unless adapter

      adapter.enqueue(task_def, args)
    end
  end
end

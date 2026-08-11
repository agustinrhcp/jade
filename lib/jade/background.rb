module Jade
  # Where backgrounded tasks go. An adapter receives a port name, its
  # already-encoded arguments, and its already-encoded options, and is
  # responsible for getting them to a worker that can call
  # Jade::Tasks.dispatch with them again.
  #
  # The language has no opinion on what options mean: they are whatever the
  # caller's own Encodable produced. Each adapter names the keys it honours
  # and is expected to reject the ones it doesn't, since a queue that
  # silently ignores `queue:` is worse than one that refuses it.
  module Background
    extend self

    class NoAdapter < StandardError
      def initialize
        super(
          'No background adapter configured. Set Jade::Background.adapter to ' \
            'something responding to #enqueue(task_def, args, options).'
        )
      end
    end

    # Runs the task immediately, in this process. The default because a
    # test suite should not need Redis, and because it makes the failure
    # mode of an unconfigured app obvious rather than silent.
    module Inline
      extend self

      def enqueue(task_def, args, _options)
        Jade::Tasks.dispatch(task_def, *args)
        "inline:#{task_def}"
      end
    end

    attr_writer :adapter

    def adapter
      @adapter ||= Inline
    end

    def enqueue(task_def, args, options)
      fail NoAdapter unless adapter

      adapter.enqueue(task_def, args, options)
    end
  end
end

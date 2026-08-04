require 'jade/stdlib/intrinsics'
require 'jade/task'

module Jade
  module Stdlib
    module Task
      extend Intrinsics

      union :Task, :a, :e

      function('succeed', { value: 'a' }, 'Task(a, e)') do |value|
        Jade::Task::Literal.new(Jade::Result::Ok[value])
      end

      function('fail', { error: 'e' }, 'Task(a, e)') do |error|
        Jade::Task::Literal.new(Jade::Result::Err[error])
      end

      function('map', { task: 'Task(a, e)', fn: 'a -> b' }, 'Task(b, e)') do |task, fn|
        Jade::Task::Map.new(task, fn)
      end

      function('and_then', { task: 'Task(a, e)', fn: 'a -> Task(b, e)' }, 'Task(b, e)') do |task, fn|
        Jade::Task::AndThen.new(task, fn)
      end

      function('on_error', { task: 'Task(a, e)', fn: 'e -> Task(a, f)' }, 'Task(a, f)') do |task, fn|
        Jade::Task::OnError.new(task, fn)
      end

      function('map_error', { task: 'Task(a, e)', fn: 'e -> f' }, 'Task(a, f)') do |task, fn|
        Jade::Task::MapError.new(task, fn)
      end

      function('from_result', { result: 'Result(a, e)' }, 'Task(a, e)') do |result|
        Jade::Task::Literal.new(result)
      end

      function('sequence', { tasks: 'List(Task(a, e))' }, 'Task(List(a), e)') do |tasks|
        Jade::Task::Sequence.new(tasks)
      end

      function('run', { task: 'Task(a, e)' }, 'Result(a, e)') do |task|
        task.run
      end

      # Hands the task to a worker and returns its job id. The task's own
      # result and error never come back — the caller is gone by then, so
      # those belong to the queue's retries. Only the enqueue is reported.
      #
      # Semantic analysis rejects anything but a direct port call, so the
      # argument is always a Dispatch: a port name plus encoded arguments.
      function('background', { task: 'Task(a, e)' }, 'Task(String, String)') do |task|
        Jade::Task::Background.new(task, {})
      end

      # Takes options already encoded: a constrained function's Ruby block
      # never receives the Encodable dictionary, so background_with resolves
      # the encoder in its body and calls through to here.
      function(
        'background_raw',
        { task: 'Task(a, e)', options: 'Value' },
        'Task(String, String)',
        private: true,
      ) do |task, options|
        Jade::Task::Background.new(task, options)
      end

      # Options are whatever the caller declared, carried across as the wire
      # form their own Encodable produces. Jade names none of the keys: an
      # adapter's vocabulary is its own, and a set fixed here would be wrong
      # for the second adapter.
      function(
        'background_with',
        { task: 'Task(a, e)', options: 'o' },
        'Task(String, String)',
        constraints: [['Encode.Encodable', 'o']],
        body: Symbol::DerivedFunction.new(
          params: %w[task options],
          body: [:call,
            [:stdlib_fn, 'Task.background_raw'],
            [
              [:var, 'task'],
              [:call, [:impl_arg, 0, 'encoder'], [[:var, 'options']]],
            ],
          ],
        ),
      )

      implementation('Mappable',  'Task', 'map'      => 'map')
      implementation('Chainable', 'Task', 'and_then' => 'and_then')

      def self.default_imports
        [Symbol.type_ref('Task', 'Task')]
      end
    end
  end
end

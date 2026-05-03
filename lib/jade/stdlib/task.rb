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

      implementation('Mappable',  'Task', 'map'      => 'map')
      implementation('Chainable', 'Task', 'and_then' => 'and_then')

      def self.default_imports
        [Symbol.type_ref('Task', 'Task')]
      end
    end
  end
end

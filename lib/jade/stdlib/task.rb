require 'jade/stdlib/intrinsics'
require 'jade/task'

module Jade
  module Stdlib
    module Task
      extend Intrinsics

      union :Task, :a, :e

      function('succeed', { value: 'a' }, 'Task(a, e)') do |value|
        Jade::Task[-> { Jade::Result::Ok[value] }]
      end

      function('fail', { error: 'e' }, 'Task(a, e)') do |error|
        Jade::Task[-> { Jade::Result::Err[error] }]
      end

      function('map', { task: 'Task(a, e)', fn: 'a -> b' }, 'Task(b, e)') do |task, fn|
        Jade::Task[-> do
          case task.run
          in Jade::Result::Ok[value]  then Jade::Result::Ok[fn.call(value)]
          in Jade::Result::Err => err then err
          end
        end]
      end

      function('and_then', { task: 'Task(a, e)', fn: 'a -> Task(b, e)' }, 'Task(b, e)') do |task, fn|
        Jade::Task[-> do
          case task.run
          in Jade::Result::Ok[value]  then fn.call(value).run
          in Jade::Result::Err => err then err
          end
        end]
      end

      function('on_error', { task: 'Task(a, e)', fn: 'e -> Task(a, f)' }, 'Task(a, f)') do |task, fn|
        Jade::Task[-> do
          case task.run
          in Jade::Result::Ok => ok   then ok
          in Jade::Result::Err[error] then fn.call(error).run
          end
        end]
      end

      function('map_error', { task: 'Task(a, e)', fn: 'e -> f' }, 'Task(a, f)') do |task, fn|
        Jade::Task[-> do
          case task.run
          in Jade::Result::Ok => ok   then ok
          in Jade::Result::Err[error] then Jade::Result::Err[fn.call(error)]
          end
        end]
      end

      function('from_result', { result: 'Result(a, e)' }, 'Task(a, e)') do |result|
        Jade::Task[-> { result }]
      end

      function('sequence', { tasks: 'List(Task(a, e))' }, 'Task(List(a), e)') do |tasks|
        Jade::Task[-> do
          tasks.reduce(Jade::Result::Ok[[]]) do |acc, task|
            case acc
            in Jade::Result::Err then acc
            in Jade::Result::Ok[values]
              case task.run
              in Jade::Result::Ok[value] then Jade::Result::Ok[values + [value]]
              in Jade::Result::Err => err then err
              end
            end
          end
        end]
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

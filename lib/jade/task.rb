require 'jade/tasks'

# Predeclare Result so Jade::Task and Jade::Tasks::Outcome work in isolation
# (without the Jade stdlib having compiled the Result module yet). When the
# stdlib later compiles Result.jd, it harmlessly re-assigns these constants.
module ::Result
  Ok  = Data.define(:_1) unless const_defined?(:Ok, false)
  Err = Data.define(:_1) unless const_defined?(:Err, false)
end

module Jade
  module Task
    def self.ok(&block)    = Literal.new(::Result::Ok[block.call])
    def self.error(&block) = Literal.new(::Result::Err[block.call])
    def self.succeed(value) = Literal.new(::Result::Ok[value])
    def self.fail(error)    = Literal.new(::Result::Err[error])

    Literal = Data.define(:result) do
      include Task
      def run = result
    end

    Dispatch = Data.define(:task_def, :args) do
      include Task
      def run = Jade::Tasks.dispatch(task_def, *args)
    end

    Map = Data.define(:task, :fn) do
      include Task

      def run
        case task.run
        in ::Result::Ok[value]  then ::Result::Ok[fn.call(value)]
        in ::Result::Err => err then err
        end
      end
    end

    AndThen = Data.define(:task, :fn) do
      include Task

      def run
        case task.run
        in ::Result::Ok[value]  then fn.call(value).run
        in ::Result::Err => err then err
        end
      end
    end

    OnError = Data.define(:task, :fn) do
      include Task

      def run
        case task.run
        in ::Result::Ok => ok    then ok
        in ::Result::Err[error]  then fn.call(error).run
        end
      end
    end

    MapError = Data.define(:task, :fn) do
      include Task

      def run
        case task.run
        in ::Result::Ok => ok    then ok
        in ::Result::Err[error]  then ::Result::Err[fn.call(error)]
        end
      end
    end

    Sequence = Data.define(:tasks) do
      include Task

      def run
        tasks.reduce(::Result::Ok[[]]) do |acc, task|
          case acc
          in ::Result::Err then acc
          in ::Result::Ok[values]
            case task.run
            in ::Result::Ok[value]   then ::Result::Ok[values + [value]]
            in ::Result::Err => err  then err
            end
          end
        end
      end
    end

    # Wraps another task to validate its Ok/Err inner values against the
    # declared Jade types at the interop boundary.
    Guarded = Data.define(:task, :ok_type, :err_type) do
      include Task

      def run
        case task.run
        in ::Result::Ok[value]
          ::Result::Ok[Jade::Interop::Guard.guard(value, ok_type)]
        in ::Result::Err[error]
          ::Result::Err[Jade::Interop::Guard.guard(error, err_type)]
        end
      end
    end
  end
end

require 'jade/tasks'

module Jade
  module Task
    Literal = Data.define(:result) do
      include Task

      def run
        result
      end
    end

    Dispatch = Data.define(:task_def, :args) do
      include Task

      def run
        Jade::Tasks.dispatch(task_def, *args)
      end
    end

    Map = Data.define(:task, :fn) do
      include Task

      def run
        case task.run
        in Jade::Result::Ok[value]  then Jade::Result::Ok[fn.call(value)]
        in Jade::Result::Err => err then err
        end
      end
    end

    AndThen = Data.define(:task, :fn) do
      include Task

      def run
        case task.run
        in Jade::Result::Ok[value]  then fn.call(value).run
        in Jade::Result::Err => err then err
        end
      end
    end

    OnError = Data.define(:task, :fn) do
      include Task

      def run
        case task.run
        in Jade::Result::Ok => ok    then ok
        in Jade::Result::Err[error]  then fn.call(error).run
        end
      end
    end

    MapError = Data.define(:task, :fn) do
      include Task

      def run
        case task.run
        in Jade::Result::Ok => ok    then ok
        in Jade::Result::Err[error]  then Jade::Result::Err[fn.call(error)]
        end
      end
    end

    Sequence = Data.define(:tasks) do
      include Task

      def run
        tasks.reduce(Jade::Result::Ok[[]]) do |acc, task|
          case acc
          in Jade::Result::Err then acc
          in Jade::Result::Ok[values]
            case task.run
            in Jade::Result::Ok[value]   then Jade::Result::Ok[values + [value]]
            in Jade::Result::Err => err  then err
            end
          end
        end
      end
    end

    Decoded = Data.define(:task, :ok_decoder, :err_decoder) do
      include Task

      def run
        case task.run
        in Jade::Result::Ok[value]
          Jade::Result::Ok[decode(ok_decoder, value)]
        in Jade::Result::Err[error]
          Jade::Result::Err[decode(err_decoder, error)]
        end
      end

      private

      def decode(decoder, value)
        case Jade::Decode::Runner.run(decoder, value)
        in Jade::Result::Ok[v]  then v
        in Jade::Result::Err[e] then fail Jade::Interop::DecodeError.new(e, value)
        end
      end
    end

  end
end

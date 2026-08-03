require 'jade/tasks'
require 'jade/background'

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

    Background = Data.define(:task) do
      include Task

      def run
        # A port lowers to a Dispatch wrapped in Decoded; semantic analysis
        # has already rejected anything else.
        dispatch = case task
                   in Decoded(task: Dispatch => d) then d
                   in Dispatch => d then d
                   end

        dispatch => Dispatch(task_def:, args:)

        Jade::Result::Ok[Jade::Background.enqueue(task_def, args)]
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
        values = []
        tasks.each do |task|
          case task.run
          in Jade::Result::Ok[value] then values << value
          in Jade::Result::Err => err then return err
          end
        end
        Jade::Result::Ok[values]
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

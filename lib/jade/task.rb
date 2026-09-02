module Jade
  module Task
    # Every node is a value describing work, and `run` drives them from one
    # loop with an explicit stack of continuations. Composing tasks therefore
    # costs heap, not Ruby stack, so a chain built by recursion (a batch loop,
    # a retry) is bounded by memory rather than by SystemStackError.
    def run
      task = self
      pending = []

      loop do
        case task
        in AndThen[inner, fn]
          task = inner
          pending << [:ok, fn]

        in OnError[inner, fn]
          task = inner
          pending << [:err, fn]

        in Map[inner, fn]
          task = inner
          pending << [:map, fn]

        in MapError[inner, fn]
          task = inner
          pending << [:map_err, fn]

        in Decoded[inner, ok_decoder, err_decoder]
          task = inner
          pending << [:decode, [ok_decoder, err_decoder]]

        else
          result = task.step
          return result if pending.empty?

          task = resume(result, pending)
          return task if task.is_a?(Jade::Result::Ok) || task.is_a?(Jade::Result::Err)
        end
      end
    end

    private

    # Applies continuations to a settled result until one of them produces a
    # fresh task to run, or the stack empties.
    def resume(result, pending)
      until pending.empty?
        kind, fn = pending.pop

        result =
          case [kind, result]
          in [:decode, _] then Decoded.decode_result(result, *fn)
          in [:ok, Jade::Result::Ok[value]] then return fn.call(value)
          in [:err, Jade::Result::Err[error]] then return fn.call(error)
          in [:map, Jade::Result::Ok[value]] then Jade::Result::Ok[fn.call(value)]
          in [:map_err, Jade::Result::Err[error]] then Jade::Result::Err[fn.call(error)]
          else result
          end
      end

      result
    end

    Literal = Data.define(:result) do
      include Task

      def step
        result
      end
    end

    Dispatch = Data.define(:task_def, :args) do
      include Task

      def step
        Jade::Tasks.dispatch(task_def, *args)
      end
    end

    Sequence = Data.define(:tasks) do
      include Task

      def step
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

    Map = Data.define(:task, :fn) { include Task }
    AndThen = Data.define(:task, :fn) { include Task }
    OnError = Data.define(:task, :fn) { include Task }
    MapError = Data.define(:task, :fn) { include Task }

    Decoded = Data.define(:task, :ok_decoder, :err_decoder) do
      include Task

      def self.decode_result(result, ok_decoder, err_decoder)
        case result
        in Jade::Result::Ok[value]  then Jade::Result::Ok[decode(ok_decoder, value)]
        in Jade::Result::Err[error] then Jade::Result::Err[decode(err_decoder, error)]
        end
      end

      def self.decode(decoder, value)
        Jade::Decode::Runner.run!(decoder, value) do |error|
          fail Jade::Interop::DecodeError.new(error, value, source: :port_return)
        end
      end
    end
  end
end

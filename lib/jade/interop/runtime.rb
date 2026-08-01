require 'jade/interop/error'

module Jade
  module Interop
    module Runtime
      def task_call(interop_module_name, function_name, ok_decoder, err_decoder, arg_encoders)
        ->(*args) do
          interop_module_name
            .send(function_name)
            .then do |port|
              port.is_a?(Jade::TaskDef) ||
                fail(Interop::PortNotRegistered.new(interop_module_name, function_name))

              Jade::Task::Decoded.new(
                Jade::Task::Dispatch.new(port, encode_args(args, arg_encoders)),
                ok_decoder,
                err_decoder,
              )
            end
        end
      end

      # Ports are the boundary in the other direction: what Ruby gets handed is
      # encoded the same way a return value is decoded on the way back.
      def encode_args(args, encoders)
        args
          .each_with_index
          .map { |arg, i| encoders.fetch(i).call(arg) }
      end
    end
  end
end

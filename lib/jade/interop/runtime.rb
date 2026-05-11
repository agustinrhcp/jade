require 'jade/interop/error'

module Jade
  module Interop
    module Runtime
      def task_call(interop_module_name, function_name, ok_decoder, err_decoder)
        ->(*args) do
          interop_module_name
            .send(function_name)
            .then do |port|
              port.is_a?(Jade::TaskDef) ||
                fail(Interop::PortNotRegistered.new(interop_module_name, function_name))

              Jade::Task::Decoded.new(
                Jade::Task::Dispatch.new(port, args),
                ok_decoder,
                err_decoder,
              )
            end
        end
      end
    end
  end
end

require 'jade/interop/guard'
require 'jade/interop/error'

module Jade
  module Interop
    module Runtime
      def guard(interop_module_name, interop_function_name, expected_jade_type)
        ->(*args) do
          interop_module_name
            .send(interop_function_name, *args)
            .then { Interop::Guard.guard(it, expected_jade_type) }
        end
      end

      def task_call(interop_module_name, function_name, ok_type, err_type)
        ->(*args) do
          interop_module_name
            .send(function_name)
            .then do |port|
              port.is_a?(Jade::TaskDef) ||
                fail(Interop::PortNotRegistered.new(interop_module_name, function_name))

              Jade::Task::Guarded.new(
                Jade::Task::Dispatch.new(port, args),
                ok_type,
                err_type,
              )
            end
        end
      end
    end
  end
end

require 'jade/interop/guard'

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
            .then do |task_def|
              task_def.is_a?(Jade::TaskDef) ||
                fail("Expected #{interop_module_name}.#{function_name} to return a Jade::TaskDef (registered via `extend Jade::Tasks::Module; task :#{function_name}`); got #{task_def.inspect}")
              Jade::Task::Guarded.new(
                Jade::Task::Dispatch.new(task_def, args),
                ok_type,
                err_type,
              )
            end
        end
      end

      def coerce(value)
        case value
        when Hash
          kw = value.transform_keys(&:to_sym)
          Data.define(*kw.keys).new(**kw)
        else
          value
        end
      end
    end
  end
end

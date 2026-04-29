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

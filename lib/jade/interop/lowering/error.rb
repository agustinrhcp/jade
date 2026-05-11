module Jade
  module Interop
    module Lowering
      class Error
        def message
          raise NotImplementedError
        end
      end

      class TypeParamError < Error
        def initialize(type_var_name)
          @type_var_name = type_var_name
        end

        def message
          "Type param (#{@type_var_name}) cannot be lowered for interop"
        end
      end

      class FunctionError < Error
        def initialize(function_name)
          @function_name = function_name
        end

        def message
          "Function (#{@function_name}) cannot be lowered for interop"
        end
      end

    end
  end
end

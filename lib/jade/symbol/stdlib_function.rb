module Jade
  module Symbol
    StdlibFunction = Data.define(:module_name, :name, :params, :return_type, :codegen) do
      include Base

      def to_ref
        ValueRef[module_name, name]
      end
    end
  end
end

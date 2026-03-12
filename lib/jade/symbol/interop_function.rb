module Jade
  module Symbol
    InteropFunction = Data.define(
      :module_name,
      :name,
      :params,
      :return_type,
      :interop_module_name,
      :expected_type
    ) do
      include Base

      def to_ref
        ValueRef[module_name, name]
      end
    end
  end
end

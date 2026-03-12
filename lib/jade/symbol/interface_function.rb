module Jade
  module Symbol
    InterfaceFunction = Data.define(
      :module_name,
      :name,
      :interface,
      :params,
      :return_type,
      :decl_span
    ) do
      include Base

      def to_ref
        ValueRef[module_name, name]
      end
    end
  end
end

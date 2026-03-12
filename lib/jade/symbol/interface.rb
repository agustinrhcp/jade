module Jade
  module Symbol
    Interface = Data.define(:module_name, :name, :type_param, :functions, :default, :decl_span) do
      include Base

      def to_ref
        TypeRef[module_name, name]
      end
    end
  end
end

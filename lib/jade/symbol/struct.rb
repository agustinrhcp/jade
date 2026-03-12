module Jade
  module Symbol
    Struct = Data.define(:module_name, :name, :type_params, :record_type, :decl_span) do
      include Base

      def to_ref
        TypeRef[module_name, name]
      end
    end
  end
end

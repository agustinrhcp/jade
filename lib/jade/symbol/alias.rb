module Jade
  module Symbol
    Alias = Data.define(:module_name, :name, :type_params, :body, :decl_span) do
      include Base

      def to_ref
        TypeRef[module_name, name]
      end
    end
  end
end

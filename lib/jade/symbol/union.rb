module Jade
  module Symbol
    Union = Data.define(:module_name, :name, :type_params, :variants, :decl_span) do
      include Base

      def to_ref
        TypeRef[module_name, name]
      end

      def qualified_name
        [module_name, name].join('.')
      end
    end
  end
end

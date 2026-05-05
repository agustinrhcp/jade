module Jade
  module Symbol
    Union = Data.define(:module_name, :name, :type_params, :variants, :decl_span) do
      include Base

      def to_ref
        TypeRef[module_name, name]
      end

      def constructor_refs
        variants
      end
    end
  end
end

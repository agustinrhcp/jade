module Jade
  module Symbol
    Constructor = Data.define(:module_name, :name, :args, :parent, :decl_span) do
      include Base

      def to_ref
        ValueRef[module_name, name]
      end
    end
  end
end

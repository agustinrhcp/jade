module Jade
  module Symbol
    Variant = Data.define(:module_name, :name, :args, :union, :decl_span) do
      include Base

      def to_ref
        ValueRef[module_name, name]
      end
    end
  end
end

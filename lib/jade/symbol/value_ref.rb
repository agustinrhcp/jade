module Jade
  module Symbol
    ValueRef = Data.define(:module_name, :name) do
      include Symbol

      def to_ref
        self
      end

      def qualified_name
        [module_name, name].join('.')
      end
    end
  end
end

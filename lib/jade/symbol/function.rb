module Jade
  module Symbol
    Function = Data.define(:module_name, :name, :params, :return_type) do
      include Base

      def to_ref
        ValueRef[module_name, name]
      end
    end
  end
end

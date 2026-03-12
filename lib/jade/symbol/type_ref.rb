module Jade
  module Symbol
    TypeRef = Data.define(:module_name, :name) do
      include Base

      def to_ref
        self
      end
    end
  end
end

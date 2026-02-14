module Jade
  module Type
    Struct = Data.define(:name, :representation) do
      include Base

      def to_s
        name
      end

      def unbound_vars
        []
      end

      def field_names
        fields.keys
      end

      def make_rigid(val = true)
        representation.make_rigid(val)
      end
    end
  end
end

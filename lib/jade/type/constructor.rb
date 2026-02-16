module Jade
  module Type
    Constructor = Data.define(:name) do
      include Base

      def to_s
        name.split('.').last
      end

      def apply(types)
        Application[self, types]
      end

      def unbound_vars
        []
      end

      def make_rigid(_ = true)
        self
      end
    end
  end
end

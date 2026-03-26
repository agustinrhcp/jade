module Jade
  module Type
    Var = Data.define(:id, :name) do
      include Base

      def to_s
        name || id
      end

      def unbound_vars
        [self]
      end

      def ==(other)
        return false unless other.is_a?(Var)

        id == other.id
      end
    end
  end
end

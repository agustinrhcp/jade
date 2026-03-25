module Jade
  module Type
    Var = Data.define(:id, :name, :rigid) do
      include Base

      def rigid?
        rigid
      end

      def to_s
        # return id
        name || id
      end

      def unbound_vars
        [self]
      end

      def ==(other)
        return false unless other.is_a?(Var)

        id == other.id
      end

      def make_rigid(rigid_val = true)
        with(rigid: rigid_val)
      end
    end
  end
end

module Jade
  module Type
    Var = Data.define(:id, :name, :constraints, :rigid) do
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

      def add_constraints(more)
        with(constraints: (constraints + more).uniq)
      end

      def make_rigid(rigid_val = true)
        with(rigid: rigid_val)
      end
    end
  end
end

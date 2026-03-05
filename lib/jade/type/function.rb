module Jade
  module Type
    Function = Data.define(:args, :return_type, :constraints) do
      include Base

      def to_s
        args
          .map(&:to_s).join(', ')
          .then { "(#{it})"} + " -> " + return_type.to_s
      end

      def unbound_vars
        (args.flat_map(&:unbound_vars) + return_type.unbound_vars)
          .to_set.to_a
      end

      def make_rigid(val = true)
        with(args: args.map { it.make_rigid(val) })
          .with(return_type: return_type.make_rigid(val))
      end
    end
  end
end

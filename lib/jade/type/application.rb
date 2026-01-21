module Jade
  module Type
    Application = Data.define(:constructor, :args) do
      include Base

      def to_s
        "#{constructor.to_s}(#{args.map(&:to_s).join(", ")})"
      end

      def unbound_vars
        args.flat_map(&:unbound_vars)
      end

      def make_rigid(val = true)
        with(args: args.map { it.make_rigid(val) })
      end
    end
  end
end

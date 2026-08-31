module Jade
  module Type
    Function = Data.define(:args, :return_type, :display) do
      include Base
      include Displayable

      def initialize(args:, return_type:, display: nil)
        super
      end

      def identity
        [args, return_type]
      end

      def render
        args
          .map(&:to_s).join(', ')
          .then { "(#{it})"} + " -> " + return_type.to_s
      end

      def unbound_vars
        (args.flat_map(&:unbound_vars) + return_type.unbound_vars)
          .to_set.to_a
      end
    end
  end
end

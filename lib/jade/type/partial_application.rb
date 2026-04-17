module Jade
  module Type
    PartialApplication = Data.define(:constructor, :args) do
      include Base

      def to_s
        args.empty? ?
          constructor.to_s :
          "#{constructor}(_, #{args.map(&:to_s).join(', ')})"
      end

      def unbound_vars
        constructor.unbound_vars + args.flat_map(&:unbound_vars)
      end
    end
  end
end

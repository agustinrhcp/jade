module Jade
  module Type
    Application = Data.define(:constructor, :args) do
      include Base

      def to_s
        return constructor.to_s if args.empty?

        if constructor.name.start_with?('Tuple.Tuple')
          return "(#{args.map(&:to_s).join(', ')})"
        end

        "#{constructor.to_s}(#{args.map(&:to_s).join(", ")})"
      end

      def unbound_vars
        constructor.unbound_vars + args.flat_map(&:unbound_vars)
      end
    end
  end
end

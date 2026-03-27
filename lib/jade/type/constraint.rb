module Jade
  module Type
    Constraint = Data.define(:interface, :type, :origin) do
      include Base

      def unbound_vars
        type.unbound_vars
      end

      def to_s
        "#{interface} #{type.to_s}"
      end
    end
  end
end

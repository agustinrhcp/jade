module Jade
  module Type
    Unit = Data.define() do
      include Base

      def unbound_vars
        []
      end

      def to_s
        '()'
      end
    end
  end
end

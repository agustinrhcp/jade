module Jade
  module Type
    Constraint = Data.define(:interface, :type) do
      include Base

      def to_s
        "#{interface} #{type.to_s}"
      end
    end
  end
end

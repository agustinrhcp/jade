module Jade
  module Type
    module Base
      def rigid?
        unbound_vars.any?(&:rigid)
      end

      def to_s
        fail NotImplementedError
      end
    end
  end
end

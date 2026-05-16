module Jade
  module Type
    # `:unindex` is for constraints that never reach `attach_dictionary` —
    # typically deriving deps that live on impls, not call origins.
    Constraint = Data.define(:interface, :type, :origin, :index) do
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

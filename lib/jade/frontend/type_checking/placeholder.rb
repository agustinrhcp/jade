module Jade
  module Frontend
    module TypeChecking
      Placeholder = Data.define(:type, :constraints) do
        def free_vars
          type.unbound_vars + constraints.flat_map(&:unbound_vars)
        end
      end
    end
  end
end


module Jade
  module Frontend
    module TypeChecking
      Scheme = Data.define(:quantified, :type, :constraints) do
        def unbound_vars
          type.unbound_vars
        end

        def free_vars
          type.unbound_vars - quantified
        end

        def self.mono(type)
          Scheme[[], type, []]
        end
      end
    end
  end
end


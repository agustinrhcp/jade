module Jade
  module Frontend
    module TypeChecking
      Expected = Data.define(:type, :authoritative) do
        def check?
          authoritative == true
        end

        def self.check(type)
          self[type, true]
        end

        def self.infer(type)
          self[type, false]
        end

        def rigid_vars
          check? ? type.unbound_vars : []
        end
      end
    end
  end
end

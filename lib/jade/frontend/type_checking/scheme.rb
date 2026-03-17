module Jade
  module Frontend
    module TypeChecking
      Scheme = Data.define(:quantified, :type, :constraints) do
        def initialize(quantified:, type:, constraints: [])
          super
        end

        def unbound_vars
          type.unbound_vars
        end

        def free_vars
          type.unbound_vars - quantified
        end

        def self.mono(type, constraints = [])
          new(quantified: [], type:, constraints:)
        end
      end
    end
  end
end


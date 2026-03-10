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

        def self.mono(type, constraints = [])
          new([], type, constraints)
        end
      end

      module Generalization
        extend self

        def generalize(env, type, constraints = [])
          (type.unbound_vars + constraints.flat_map(&:unbound_vars))
            .to_set
            .to_a
            .then { it - env.free_vars }
            .then { Scheme[it, type, constraints] }
        end
      end
    end
  end
end


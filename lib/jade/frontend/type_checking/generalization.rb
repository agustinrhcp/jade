module Jade
  module Frontend
    module TypeChecking
      module Generalization
        extend self

        def generalize(env, type, constraints = [])
          (type.unbound_vars + constraints.flat_map(&:unbound_vars))
            .uniq(&:id)
            .then { it - env.free_vars }
            .then { Scheme[it, type, constraints] }
        end
      end
    end
  end
end


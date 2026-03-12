module Jade
  module Frontend
    module TypeChecking
      module Generalization
        extend self

        def generalize(env, type)
          (type.unbound_vars - env.free_vars)
            .then { Scheme[it, type] }
        end
      end
    end
  end
end


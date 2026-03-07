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
          new([], type, type.constraints)
        end
      end

      module Generalization
        extend self

        def generalize(env, type)
          (type.unbound_vars - env.free_vars)
            .then { Scheme[it, type, type.respond_to?(:constraints) ? type.constraints : []] }
        end
      end
    end
  end
end


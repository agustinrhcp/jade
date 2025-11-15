module Jade
  module Frontend
    module TypeChecking

      Scheme = Data.define(:quantified, :type)

      module Generalization
        extend self

        def generalize(type)
          Scheme[type.free_vars, type]
        end
      end
    end
  end
end


module Jade
  module Frontend
    module TypeChecking
      module Instantiation
        extend self

        def instantiate(scheme, var_gen)
          scheme
            .quantified.reduce(Substitution.new) do |subs, var|
              subs.bind(var, Type.var(var_gen.fresh))
            end
            .then { it.apply(scheme.type) }
        end
      end
    end
  end
end

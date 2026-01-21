module Jade
  module Frontend
    module TypeChecking
      module Instantiation
        extend self

        def instantiate(scheme, var_gen)
          scheme
            .quantified.reduce(Substitution.new) do |subs, var|
              subs.bind(var.id, Type.var(var_gen.fresh, var.name))
            end
            .then { it.apply(scheme.type) }
        end
      end
    end
  end
end

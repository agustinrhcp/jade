module Jade
  module Frontend
    module TypeChecking
      module Instantiation
        extend self

        def instantiate(scheme, var_gen)
          sub = scheme
            .quantified.reduce(Substitution.new) do |subs, var|
              subs.bind(var.id, var_gen.fresh(var.name))
            end

          scheme
            .constraints
            .map { sub.apply(it) }
            .then { [sub.apply(scheme.type), it] }
        end
      end
    end
  end
end

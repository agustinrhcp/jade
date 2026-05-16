module Jade
  module Frontend
    module TypeChecking
      module Instantiation
        extend self

        # Index = position in scheme.constraints. Lets attach_dictionary write
        # positionally so sibling same-iface markers don't collide on one origin.
        def instantiate(scheme, var_gen)
          sub = scheme
            .quantified.reduce(Substitution::EMPTY) do |subs, var|
              subs.bind(var.id, var_gen.fresh(var.name))
            end

          scheme
            .constraints
            .each_with_index
            .map { |c, i| sub.apply(c.with(index: i)) }
            .then { [sub.apply(scheme.type), it] }
        end
      end
    end
  end
end

module Jade
  module Frontend
    module TypeChecking
      module Instantiation
        extend self

        def instantiate(scheme, var_gen)
          sub = scheme
            .quantified
            .reduce(Substitution.new) do |subs, var|
              var_gen
                .fresh(var.name)
                .then { subs.bind(var.id, it) }
            end

          scheme
            .constraints
            .map { sub.apply(it) }
            .then {  [sub.apply(scheme.type), it] }
        end
      end
    end
  end
end

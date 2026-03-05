module Jade
  module Frontend
    module TypeChecking
      module Instantiation
        extend self

        def instantiate(scheme, var_gen)
          scheme
            .quantified.reduce(Substitution.new) do |subs, var|
              constraints = scheme
                .constraints
                .select { it.type.name == var.name }

              var_gen.fresh(var.name).with(constraints:)
                .then { subs.bind(var.id, it) }
            end
            .then { it.apply(scheme.type) }
        end
      end
    end
  end
end

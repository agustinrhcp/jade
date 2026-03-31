module Jade
  module Frontend
    module TypeChecking
      module Generalizer
        extend self
        include Inference::Helpers

        def generalize(env)
          env
            .bindings
            .reduce(env) do |e, (k, binding)|
              case binding
              in Placeholder(type:, constraints:)
                unbound_cs = constraints
                  .map { e.substitution.apply(it) }
                  .uniq
                  .select { it.unbound_vars.any? }

                Generalization.
                  generalize(
                    # Remove the current placeholder from the bindings.
                    #   So the placeholder vars don't appear on
                    #   the env free_vars
                    e.with(bindings: e.bindings.except(k)),
                    e.substitution.apply(type),
                    unbound_cs,
                  )
                  .then { e.bind(k, it) }
              else

                next e
              end
            end
        end
      end
    end
  end
end

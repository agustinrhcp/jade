module Jade
  module Frontend
    module TypeChecking
      # Type-var ids must be unique across every scheme that ever flows
      # through unification. Per-instance counters made cross-module
      # imports fragile: a fresh id from one module could equal a
      # quantified id from another, aliasing them through
      # Substitution.apply. A class-level counter makes collisions
      # impossible by construction.
      class VarGen
        @counter = 0

        class << self
          attr_accessor :counter
        end

        def fresh_id
          "t#{self.class.counter += 1}"
        end

        def fresh(name = nil)
          fresh_id
            .then { Type.var(it, name) }
        end

        def next(name)
          "#{name}#{self.class.counter += 1}"
            .then { Type.var(it, name) }
        end
      end
    end
  end
end

module Jade
  module Frontend
    module TypeChecking
      Result = Data.define(:type, :constraints) do
        def self.init(type, constraints = [])
          new(type, constraints)
        end

        def apply(substitution)
          with(type: substitution.apply(type))
        end

        def map(&block)
          block
            .call(type)
            .then { with(type: it) }
        end

        def attach_origin(node)
          constraints
            .map { it.with(origin: it.origin || node )}
            .then { with(constraints: it) }
        end

        def self.accumulator
          ResultAcc[[], []]
        end
      end

      ResultAcc = Data.define(:types, :constraints) do
        def add(result)
          with(
            types: types + [result.type],
            constraints: constraints + result.constraints,
          )
        end
      end
    end
  end
end

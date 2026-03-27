module Jade
  module Frontend
    module TypeChecking
      Result = Data.define(:type) do
        def self.init(type)
          new(type)
        end

        def apply(substitution)
          with(type: substitution.apply(type))
        end

        def map(&block)
          block
            .call(type)
            .then { with(type: it) }
        end

        def self.accumulator
          ResultAcc[[]]
        end
      end

      ResultAcc = Data.define(:types) do
        def add(result)
          with(types: types + [result.type])
        end
      end
    end
  end
end

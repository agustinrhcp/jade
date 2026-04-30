require_relative './deriving/eq.rb'
require_relative './deriving/decodable.rb'

module Jade
  module Frontend
    module TypeChecking
      module Constraints
        module Deriving
          extend self

          DERIVERS = [Eq, Decodable]

          def derivable?(interface)
            DERIVERS.any? { it.supports?(interface) }
          end

          def derive(constraint, registry, entry_name, &lookup)
            DERIVERS
              .find { it.supports?(constraint.interface) }
              .then { it.derive(constraint, registry, entry_name, &lookup) }
          end
        end
      end
    end
  end
end

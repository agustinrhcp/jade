require_relative './deriving/helpers.rb'
require_relative './deriving/eq.rb'
require_relative './deriving/decodable.rb'
require_relative './deriving/encodable.rb'
require_relative './deriving/show.rb'

module Jade
  module Frontend
    module TypeChecking
      module Constraints
        module Deriving
          extend self

          BUILTIN = [Eq, Show, Decodable, Encodable].freeze

          def derivers = BUILTIN + Extensions.derivers

          def derivable?(interface)
            derivers.any? { it.supports?(interface) }
          end

          def derive(constraint, registry, entry_name, &lookup)
            derivers
              .find { it.supports?(constraint.interface) }
              .then { it.derive(constraint, registry, entry_name, &lookup) }
          end
        end
      end
    end
  end
end

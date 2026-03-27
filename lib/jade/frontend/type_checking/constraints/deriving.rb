require_relative './deriving/eq.rb'

module Jade
  module Frontend
    module TypeChecking
      module Constraints
        module Deriving
          extend self

          def derivable?(interface)
            Eq.supports?(interface)
          end

          def derive(constraint, registry, entry_name, &lookup)
            Eq.derive(constraint, registry, entry_name, &lookup)
          end
        end
      end
    end
  end
end

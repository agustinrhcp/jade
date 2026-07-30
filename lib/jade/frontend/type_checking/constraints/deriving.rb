require_relative './deriving/helpers.rb'
require_relative './deriving/eq.rb'
require_relative './deriving/decodable.rb'
require_relative './deriving/encodable.rb'

module Jade
  module Frontend
    module TypeChecking
      module Constraints
        module Deriving
          extend self

          BUILT_IN = [Eq, Decodable, Encodable].freeze

          # An extension gem derives instances of its own interfaces by
          # registering one of these. Built-ins are consulted first, so a
          # gem cannot take over Eq, Encodable or Decodable.
          def register(deriver)
            %i[supports? derive]
              .reject { deriver.respond_to?(it) }
              .then { fail ArgumentError, "deriver must respond to #{it.join(', ')}" if it.any? }

            registered << deriver unless registered.include?(deriver)
            deriver
          end

          def registered
            @registered ||= []
          end

          def derivers
            BUILT_IN + registered
          end

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

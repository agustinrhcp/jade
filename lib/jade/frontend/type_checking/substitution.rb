module Jade
  module Frontend
    module TypeChecking
      Substitution = Data.define(:mappings) do
        def initialize(mappings: {})
          super
        end

        def apply(type)
          case type
          in Type::Constructor
            type
          end
        end

        def compose(other)
          other_applied_to_self = mappings
            .transform_values { |t| other.apply(t) }
            .then { Substitution[it] }

          self_applied_to_other = other.mappings
            .transform_values { |t| other_applied_to_self.apply(t) }

          composed = other_applied_to_self.mappings
            .merge(self_applied_to_other)
            .then { Substitution[it] }

          # stabilize
          composed
            .mappings
            .transform_values { |t| composed.apply(t) }
            .then { Substitution[it] }
        end
      end
    end
  end
end

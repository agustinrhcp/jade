module Jade
  module Frontend
    module TypeChecking
      module Error
        class UnresolvedConstraint < Jade::Error
          def initialize(entry, span, constraint:)
            @constraint = constraint
            super(entry:, span:)
          end

          def message
            "Unresolved constraint: #{@constraint.interface} #{@constraint.type}"
          end
        end
      end
    end
  end
end

module Jade
  module Frontend
    module TypeChecking
      module Error
        class UnsatisfiedConstraint < Jade::Error
          def initialize(entry, span, constraint:)
            @constraint = constraint
            super(entry:, span:)
          end

          def message
            "Cannot satisfy #{@constraint.interface.qualified_name} constraint"
          end
        end
      end
    end
  end
end

module Jade
  module Frontend
    module TypeChecking
      module Error
        class MissingImplementation < Jade::Error
          attr_reader :constraint

          def initialize(entry, span, constraint:)
            @constraint = constraint
            super(entry:, span:)
          end

          def message
            "No implementation of #{@constraint.interface} for #{@constraint.type}"
          end
        end
      end
    end
  end
end

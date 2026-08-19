module Jade
  module Frontend
    module TypeChecking
      module Error
        class DerivationFailed < Jade::Error
          attr_reader :constraint

          def initialize(entry, span, constraint:, trace: [], reason: nil)
            @constraint = constraint
            @trace = trace
            @reason = reason
            super(entry:, span:)
          end

          def message
            "#{@constraint.interface} cannot be derived for #{@constraint.type}"
              .then { @reason ? "#{it}: #{@reason}" : it }
          end
        end
      end
    end
  end
end

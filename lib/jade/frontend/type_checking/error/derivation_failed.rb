module Jade
  module Frontend
    module TypeChecking
      module Error
        class DerivationFailed < Jade::Error
          attr_reader :constraint

          def initialize(entry, span, constraint:, trace: [])
            @constraint = constraint
            @trace = trace
            super(entry:, span:)
          end

          def message
            "#{@constraint.interface} cannot be derived for #{@constraint.type}"
          end
        end
      end
    end
  end
end

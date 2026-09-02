module Jade
  module Frontend
    module TypeChecking
      module Error
        class RecursiveDerivation < Jade::Error
          attr_reader :constraint

          def initialize(entry, span, constraint:)
            @constraint = constraint
            super(entry:, span:)
          end

          def message
            "#{@constraint.interface} cannot be derived for #{@constraint.type} " \
              'because it contains itself; write the implementation by hand'
          end

          def label
            "#{@constraint.type} is recursive"
          end
        end
      end
    end
  end
end

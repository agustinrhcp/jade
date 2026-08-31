module Jade
  module Frontend
    module TypeChecking
      module Error
        class EmptyRangePattern < Jade::Error
          include PatternProblem
          def initialize(entry, span, from:, to:)
            @from = from
            @to = to
            super(entry:, span:)
          end

          def message
            "#{@from}..#{@to} matches nothing, because #{@from} is greater " \
              "than #{@to}."
          end

          def label
            'empty range'
          end
        end
      end
    end
  end
end

module Jade
  module Frontend
    module SemanticAnalysis
      module Error
        class KwargsOnNonConstructor < Jade::Error
          def initialize(entry, span)
            super(entry:, span:)
          end

          def message
            "Keyword-argument syntax is only valid for struct or variant constructors"
          end
        end
      end
    end
  end
end

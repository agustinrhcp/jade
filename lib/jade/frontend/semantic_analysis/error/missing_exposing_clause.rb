module Jade
  module Frontend
    module SemanticAnalysis
      module Error
        class MissingExposingClause < Jade::Error
          def initialize(entry, span)
            super(entry:, span:)
          end

          def message
            "This module is missing an exposing clause"
          end
        end
      end
    end
  end
end

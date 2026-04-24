module Jade
  module Frontend
    module SemanticAnalysis
      module Error
        class InvalidListRestPattern < Jade::Error
          def initialize(entry, span)
            super(entry:, span:)
          end

          def message
            "List rest pattern must be a name (e.g. `xs`) or wildcard (`_`)"
          end
        end
      end
    end
  end
end

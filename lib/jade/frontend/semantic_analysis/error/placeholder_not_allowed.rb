module Jade
  module Frontend
    module SemanticAnalysis
      module Error
        class PlaceholderNotAllowed < Jade::Error
          def initialize(entry, span, field:)
            @field = field
            super(entry:, span:)
          end

          def message
            "`#{@field}: _` is only allowed when constructing a struct"
          end

          def label
            "not allowed here"
          end
        end
      end
    end
  end
end

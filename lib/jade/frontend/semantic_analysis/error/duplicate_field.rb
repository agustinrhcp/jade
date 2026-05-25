module Jade
  module Frontend
    module SemanticAnalysis
      module Error
        class DuplicateField < Jade::Error
          def initialize(entry, span, field:)
            @field = field
            super(entry:, span:)
          end

          def message
            "Field `#{@field}:` was given more than once"
          end
        end
      end
    end
  end
end

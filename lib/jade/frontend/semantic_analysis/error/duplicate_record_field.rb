module Jade
  module Frontend
    module SemanticAnalysis
      module Error
        class DuplicateRecordField < Jade::Error
          def initialize(entry, span, field_name:, duplicate_spans:)
            super(entry:, span:)
            @field_name = field_name
            @duplicate_spans = duplicate_spans
          end

          def message
            "This record has multipe `#{field_name}` fields"
          end
        end
      end
    end
  end
end

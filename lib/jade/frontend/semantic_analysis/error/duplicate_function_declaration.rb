module Jade
  module Frontend
    module SemanticAnalysis
      module Error
        class DuplicateFunctionDeclaration < Jade::Error
          attr_reader :duplicate_spans

          def initialize(entry, span, name, duplicate_spans:)
            @name = name
            @duplicate_spans = duplicate_spans
            super(entry:, span:)
          end

          def message
            "Duplicate function definition `#{@name}` (#{duplicate_spans.size + 1} declarations)"
          end

          def label
            "already defined"
          end
        end
      end
    end
  end
end

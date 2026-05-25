module Jade
  module Frontend
    module SemanticAnalysis
      module Error
        class VariableNotFound < Jade::Error
          attr_reader :causes

          def initialize(entry, span, name:, causes: [])
            @name = name
            @causes = causes
            super(entry:, span:)
          end

          def message
            "I cannot find a `#{@name}` variable"
          end

          def label
            "not found"
          end
        end
      end
    end
  end
end

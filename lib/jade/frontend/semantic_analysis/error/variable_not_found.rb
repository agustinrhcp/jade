module Jade
  module Frontend
    module SemanticAnalysis
      module Error
        class VariableNotFound < Jade::Error
          attr_reader :causes, :candidates

          def initialize(entry, span, name:, causes: [], candidates: [])
            @name = name
            @causes = causes
            @candidates = candidates
            super(entry:, span:)
          end

          def message
            "I cannot find a `#{@name}` variable"
          end

          def label
            "not found"
          end

          # Qualified, like `candidates`: bare `fold_left` against `fold` is
          # too short to clear the spell checker's threshold.
          def queried_name
            @name
          end
        end
      end
    end
  end
end

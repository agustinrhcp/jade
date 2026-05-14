module Jade
  module Frontend
    module SemanticAnalysis
      module Error
        class DuplicateFunctionDeclaration < Jade::Error
          def initialize(entry, span, name)
            @name = name
            super(entry:, span:)
          end

          def message
            "Duplicate function definition `#{@name}`"
          end

          def label
            "already defined"
          end
        end
      end
    end
  end
end

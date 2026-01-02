module Jade
  module Frontend
    module SemanticAnalysis
      module Error
        class DuplicateFunctionDeclaration < ::Error
          def initialize(entry, span, name)
            @name = name
            super(entry:, span:)
          end

          def message
            "Duplicate function definition `#{@name}`"
          end
        end
      end
    end
  end
end

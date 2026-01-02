module Jade
  module Frontend
    module SemanticAnalysis
      module Error
        class DuplicateFunctionDeclaration < ::Error
          def initialize(node)
            super()
            @node = node
          end

          def message
            @node => AST::FunctionDeclaration(name:)

            "Duplicate function definition `#{name}`"
          end
        end
      end
    end
  end
end

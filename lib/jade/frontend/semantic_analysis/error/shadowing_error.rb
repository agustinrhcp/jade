module Jade
  module Frontend
    module SemanticAnalysis
      module Error
        class ShadowingError < Jade::Error
          def initialize(entry, span, name:)
            super(entry:, span:)
            @name = name
          end

          def message
            "Variable #{@name} shadows existing variable"
          end
        end
      end
    end
  end
end

module Jade
  module Frontend
    module SemanticAnalysis
      module Error
        class UndefinedVariable < Jade::Error
          def initialize(entry, span, var_ref:)
            super(entry:, span:)
            @var_ref = var_ref
          end

          def message
            "Undefined variable #{@var_ref}"
          end
        end
      end
    end
  end
end

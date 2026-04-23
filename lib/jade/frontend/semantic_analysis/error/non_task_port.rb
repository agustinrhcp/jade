module Jade
  module Frontend
    module SemanticAnalysis
      module Error
        class NonTaskPort < Jade::Error
          def initialize(entry, span, fn_name:)
            super(entry:, span:)
            @fn_name = fn_name
          end

          def message
            "Port `#{@fn_name}` must return a Task type, e.g. `#{@fn_name}: Task(Ok, Err)`"
          end
        end
      end
    end
  end
end

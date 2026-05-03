module Jade
  module Frontend
    module SemanticAnalysis
      module Error
        class NestedTaskPort < Jade::Error
          def initialize(entry, span, fn_name:)
            super(entry:, span:)
            @fn_name = fn_name
          end

          def message
            "Port `#{@fn_name}` declares a Task whose Ok or Err arm is itself a Task; " \
              "tasks must not return tasks — compose with map/and_then/sequence in Jade instead"
          end
        end
      end
    end
  end
end

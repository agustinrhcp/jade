module Jade
  module Frontend
    module SemanticAnalysis
      module Error
        class PredicateMustReturnBool < Jade::Error
          def initialize(entry, span, fn_name:)
            super(entry:, span:)
            @fn_name = fn_name
          end

          def message
            "`#{@fn_name}` ends in `?` so it must return `Bool`."
          end

          def label
            "expected `Bool` return"
          end
        end
      end
    end
  end
end

module Jade
  module Frontend
    module SemanticAnalysis
      module Error
        class UnboundTypeVariable < Jade::Error
          def initialize(entry, span, type_name:, variables:)
            super(entry:, span:)
            @type_name = type_name
            @variables = variables
          end

          def message
            @variables
              .map { "`#{it}`" }
              .join(', ')
              .then { "Type `#{@type_name}` has unbound variables #{it}" }
          end
        end
      end
    end
  end
end

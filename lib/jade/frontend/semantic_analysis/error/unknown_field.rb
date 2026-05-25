module Jade
  module Frontend
    module SemanticAnalysis
      module Error
        class UnknownField < Jade::Error
          def initialize(entry, span, type_name:, field:, expected:)
            @type_name = type_name
            @field = field
            @expected = expected
            super(entry:, span:)
          end

          def message
            "`#{@type_name}` has no field `#{@field}` (has: #{@expected.map { "`#{it}`" }.join(', ')})"
          end
        end
      end
    end
  end
end

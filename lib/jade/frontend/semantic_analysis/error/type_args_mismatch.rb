module Jade
  module Frontend
    module SemanticAnalysis
      module Error
        class TypeArgsMismatch < Jade::Error
          def initialize(entry, span, type_name:, expected:, actual:)
            super(entry:, span:)
            @type_name = type_name
            @expected = expected
            @actual = actual
          end

          def message
            "`#{@type_name}` type needs #{@expected}" +
              " argument#{@expected > 1 ? 's' : ''} but got #{@actual}"
          end
        end
      end
    end
  end
end

module Jade
  module Frontend
    module TypeChecking
      module Error
        class TypeMismatch < Jade::Error
          def initialize(entry, span, expected:, actual:, **)
            @expected = expected
            @actual = actual
            super(entry:, span:)
          end

          def message
            "Expected #{@expected} but got #{@actual}"
          end
        end
      end
    end
  end
end

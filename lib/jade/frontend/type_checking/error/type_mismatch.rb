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
            "Expected #{naming.annotated(@expected)} but got #{naming.annotated(@actual)}"
          end

          def label
            "expected #{naming[@expected]}, got #{naming[@actual]}"
          end

          attr_reader :expected, :actual

          private

          def naming
            @naming ||= Display.naming(@expected, @actual)
          end
        end
      end
    end
  end
end

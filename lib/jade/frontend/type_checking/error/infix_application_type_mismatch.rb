module Jade
  module Frontend
    module TypeChecking
      module Error
        class InfixApplicationTypeMismatch < TypeMismatch
          def initialize(entry, span, expected:, actual:, operator:, side:)
            super
            @side = side == :left ? 'Left' : 'Right'
            @operator = operator
          end

          def message
            "#{@side} side of (#{@operator}) expects #{@expected} but found #{@actual}"
          end
        end
      end
    end
  end
end

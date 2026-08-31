module Jade
  module Frontend
    module TypeChecking
      module Error
        class DivisionByZero < Jade::Error
          def initialize(entry, span)
            super(entry:, span:)
          end

          def message
            'Cannot divide by zero.'
          end

          def label
            'this divisor is zero'
          end

          def notes
            [
              Jade::Diagnostics::Annotation[
                :help,
                'division takes a `NonZero`. A literal other than zero is one; ' \
                  'for a value, `non_zero(n)` gives a `Maybe(NonZero(a))`',
              ],
            ]
          end
        end
      end
    end
  end
end

module Jade
  module Frontend
    module ForwardDeclaration
      module Error
        class TupleArityOverflow < Jade::Error
          MAX_ARITY = 4

          def initialize(entry, span, arity:)
            super(entry:, span:)
            @arity = arity
          end

          def message
            "Tuple of #{@arity} items is too big — tuples cap at #{MAX_ARITY}. " \
              "Use a record or a struct."
          end

          def label
            "#{@arity}-tuple"
          end
        end
      end
    end
  end
end

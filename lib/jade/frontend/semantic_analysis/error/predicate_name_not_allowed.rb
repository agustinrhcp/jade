module Jade
  module Frontend
    module SemanticAnalysis
      module Error
        # Names ending in `?` are reserved for function declarations. Using
        # the `?` suffix on a variable, parameter, or destructured binding
        # would let a non-Bool value shadow the predicate convention.
        class PredicateNameNotAllowed < Jade::Error
          def initialize(entry, span, name:)
            super(entry:, span:)
            @name = name
          end

          def message
            "`#{@name}` ends in `?` but only function names may use that suffix."
          end

          def label
            "`?` only on function names"
          end
        end
      end
    end
  end
end

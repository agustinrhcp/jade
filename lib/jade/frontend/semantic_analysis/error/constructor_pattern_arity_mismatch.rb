module Jade
  module Frontend
    module SemanticAnalysis
      module Error
        class ConstructorPatternArityMismatch < Jade::Error
          def initialize(entry, span, constructor:, expected_arity:, actual_arity:)
            super(entry:, span:)
            @constructor = constructor
            @expected_arity = expected_arity
            @actual_arity = actual_arity
          end

          def message
            "Arity mismatch, #{@constructor} expects #{@expected_arity} patterns but found #{@actual_arity}"
          end

          def label
            "expected #{@expected_arity} pattern#{@expected_arity > 1 ? 's' : ''}, got #{@actual_arity}"
          end
        end
      end
    end
  end
end

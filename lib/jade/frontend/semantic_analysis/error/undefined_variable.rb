module Jade
  module Frontend
    module SemanticAnalysis
      module Error
        class UndefinedVariable < Jade::Error
          attr_reader :candidates

          def initialize(entry, span, var_ref:, candidates: [])
            super(entry:, span:)
            @var_ref = var_ref
            @candidates = candidates
          end

          def message
            "Undefined variable #{@var_ref}"
          end

          def label
            "undefined"
          end

          def queried_name
            @var_ref
          end
        end
      end
    end
  end
end

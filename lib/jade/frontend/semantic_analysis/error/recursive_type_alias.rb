module Jade
  module Frontend
    module SemanticAnalysis
      module Error
        class RecursiveTypeAlias < Jade::Error
          def initialize(entry, span, name:, cycle:)
            super(entry:, span:)
            @name = name
            @cycle = cycle
          end

          def message
            "Type alias `#{@name}` is recursive (cycle: #{@cycle.join(' -> ')}). " \
              "Aliases must be finite — use `type` (union) for recursive shapes."
          end

          def label
            "recursive type alias"
          end
        end
      end
    end
  end
end

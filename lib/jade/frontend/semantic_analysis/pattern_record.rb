module Jade
  module Frontend
    module SemanticAnalysis
      module PatternRecord
        extend self
        extend Helper

        def analyze(node, registry, scope, entry)
          node => AST::Pattern::Record(fields:)

          analyze_many(fields.map(&:pattern), registry, scope, entry)
        end
      end
    end
  end
end

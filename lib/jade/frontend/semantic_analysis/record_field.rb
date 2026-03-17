module Jade
  module Frontend
    module SemanticAnalysis
      module RecordField
        extend self
        extend Helper

        def analyze(node, registry, scope, entry)
          node => AST::RecordField(value:)

          analyze_node(value, registry, scope, entry)
        end
      end
    end
  end
end

module Jade
  module Frontend
    module SemanticAnalysis
      module Grouping
        extend self
        extend Helper

        def analyze(node, registry, scope, entry)
          node => AST::Grouping(expression:)

          analyze_node(expression, registry, scope, entry)
            .map_node { node.with(expression: it) }
        end
      end
    end
  end
end

module Jade
  module Frontend
    module SemanticAnalysis
      module PatternLiteral
        extend self
        extend Helper

        def analyze(node, registry, scope, entry)
          node => AST::Pattern::Literal(literal:)

          analyze_node(literal, registry, scope, entry)
            .then { Result.combine(node, scope:, literal: it) }
        end
      end
    end
  end
end

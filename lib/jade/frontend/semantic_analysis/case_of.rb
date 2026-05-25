module Jade
  module Frontend
    module SemanticAnalysis
      module CaseOf
        extend self
        extend Helper

        def analyze(node, registry, scope, entry)
          node => AST::CaseOf(expression:, branches:)

          Result.combine(node, scope:,
            expression: analyze_node(expression, registry, scope, entry),
            branches: analyze_in_parallel(branches, registry, scope, entry),
          )
        end
      end
    end
  end
end

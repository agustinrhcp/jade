module Jade
  module Frontend
    module SemanticAnalysis
      module Assign
        extend self
        extend Helper

        def analyze(node, registry, scope, entry)
          node => AST::Assign(pattern:, expression:)

          ptn_r = analyze_node(pattern, registry, scope, entry)
          Result.combine(node, scope: ptn_r.scope,
            pattern: ptn_r,
            expression: analyze_node(expression, registry, scope, entry),
          )
        end
      end
    end
  end
end

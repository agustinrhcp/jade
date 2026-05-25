module Jade
  module Frontend
    module SemanticAnalysis
      module CaseOfBranch
        extend self
        extend Helper

        def analyze(node, registry, scope, entry)
          node => AST::CaseOfBranch(pattern:, body:)

          ptn_r = analyze_node(pattern, registry, scope, entry)
          Result.combine(node, scope:,
            pattern: ptn_r,
            body: analyze_node(body, registry, ptn_r.scope, entry),
          )
        end
      end
    end
  end
end

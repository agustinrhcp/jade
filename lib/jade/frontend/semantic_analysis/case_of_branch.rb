module Jade
  module Frontend
    module SemanticAnalysis
      module CaseOfBranch
        extend self
        extend Helper

        def analyze(node, registry, scope, entry)
          node => AST::CaseOfBranch(pattern:, body:)

          analyze_node(pattern, registry, scope, entry) => { scope: ptn_scope, errors: ptn_errors }
          analyze_node(body, registry, ptn_scope, entry) => { errors: body_errors }

          # TODO: Analyze unreachability
          Result[scope, ptn_errors + body_errors]
        end
      end
    end
  end
end

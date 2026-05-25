module Jade
  module Frontend
    module SemanticAnalysis
      module IfThenElse
        extend self
        extend Helper

        def analyze(node, registry, scope, entry)
          node => AST::IfThenElse(condition:, if_branch:, else_branch:)

          Result.combine(node, scope:,
            condition: analyze_node(condition, registry, scope, entry),
            if_branch: analyze_node(if_branch, registry, scope, entry),
            else_branch: analyze_node(else_branch, registry, scope, entry),
          )
        end
      end
    end
  end
end

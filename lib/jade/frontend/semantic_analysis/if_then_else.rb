module Jade
  module Frontend
    module SemanticAnalysis
      module IfThenElse
        extend self
        extend Helper

        def analyze(node, registry, scope, entry)
          node => AST::IfThenElse(condition:, if_branch:, else_branch:)

          analyze_node(condition, registry, scope, entry) => { errors: condition_errors }
          analyze_node(if_branch, registry, scope, entry) => { errors: if_errors }
          analyze_node(else_branch, registry, scope, entry) => { errors: else_errors }

          Result[scope, condition_errors + if_errors + else_errors]
        end
      end
    end
  end
end

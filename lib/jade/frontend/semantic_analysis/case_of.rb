module Jade
  module Frontend
    module SemanticAnalysis
      module CaseOf
        extend self
        extend Helper

        def analyze(node, registry, scope, entry)
          node => AST::CaseOf(expression:, branches:)

          analyze_node(expression, registry, scope, entry) => { errors: exp_errors }

          analyze_many(branches, registry, scope, entry)
            .add_errors(exp_errors)
        end
      end
    end
  end
end

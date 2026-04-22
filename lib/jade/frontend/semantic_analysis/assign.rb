module Jade
  module Frontend
    module SemanticAnalysis
      module Assign
        extend self
        extend Helper

        def analyze(node, registry, scope, entry)
          node => AST::Assign(pattern:, expression:)

          analyze_node(expression, registry, scope, entry) => { errors: expr_errors }

          analyze_node(pattern, registry, scope, entry)
            .add_errors(expr_errors)
        end

      end
    end
  end
end

module Jade
  module Frontend
    module SemanticAnalysis
      module VariableBinding
        extend self
        extend Helper

        def analyze(node, registry, scope, entry)
          node => AST::VariableBinding(name:, expression:)

          analyze_node(expression, registry, scope, entry) => { errors: expr_errors }

          bind(scope, Symbol.var(name, node.range), entry)
            .add_errors(expr_errors)
        end
      end
    end
  end
end

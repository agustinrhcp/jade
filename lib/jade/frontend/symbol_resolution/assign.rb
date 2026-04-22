module Jade
  module Frontend
    module SymbolResolution
      module Assign
        extend self
        extend Helper

        def resolve(node, registry, current_entry)
          node => AST::Assign(pattern:, expression:)

          resolve_node(expression, registry, current_entry) => {
            node: expr_resolved, errors: expr_errors,
          }

          resolve_node(pattern, registry, current_entry)
            .map { node.with(pattern: it, expression: expr_resolved) }
            .add_errors(expr_errors)
        end
      end
    end
  end
end

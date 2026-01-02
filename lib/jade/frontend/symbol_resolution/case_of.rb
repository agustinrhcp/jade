module Jade
  module Frontend
    module SymbolResolution
      module CaseOf
        extend self
        extend Helper

        def resolve(node, registry, current_entry)
          node => AST::CaseOf(expression:, branches:)

          resolve_node(expression, registry, current_entry) => {
            node: exp_resolved, errors: exp_errors,
          }

          branches
            .map { resolve_node(it, registry, current_entry) }
            .then { Result.sequence(it) }
            .map { node.with(branches: it, expression: exp_resolved) }
            .add_errors(exp_errors)
        end
      end
    end
  end
end

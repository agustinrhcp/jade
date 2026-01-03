module Jade
  module Frontend
    module SymbolResolution
      module CaseOf
        extend self

        def resolve(node, registry, current_entry)
          node => AST::CaseOf(expression:, branches:)

          branches
            .map { SymbolResolution.resolve(it, registry, current_entry) }
            .then { node.with(branches: it) }
            .with(expression: SymbolResolution.resolve(expression, registry, current_entry))
        end
      end
    end
  end
end

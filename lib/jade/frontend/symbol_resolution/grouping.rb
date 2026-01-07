module Jade
  module Frontend
    module SymbolResolution
      module Grouping
        extend self
        extend Helper

        def resolve(node, registry, current_entry)
          node => AST::Grouping(expression:)

          resolve_node(expression, registry, current_entry)
            .map { node.with(expression: it) }
        end
      end
    end
  end
end

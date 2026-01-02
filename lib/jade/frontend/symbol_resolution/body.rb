module Jade
  module Frontend
    module SymbolResolution
      module Body
        extend self
        extend Helper

        def resolve(node, registry, current_entry)
          node => AST::Body(expressions:)

          expressions
            .map { resolve_node(it, registry, current_entry) }
            .then { Result.sequence(it) }
            .map { node.with(expressions: it) }
        end
      end
    end
  end
end

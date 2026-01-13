module Jade
  module Frontend
    module SymbolResolution
      module List
        extend self
        extend Helper

        def resolve(node, registry, current_entry)
          node => AST::List(items:)

          symbol = Symbol::TypeRef['List', 'List']
            
          items
            .map { resolve_node(it, registry, current_entry) }
            .then { Result.sequence(it) }
            .map { node.with(items: it, symbol:) }
        end
      end
    end
  end
end

module Jade
  module Frontend
    module SemanticAnalysis
      module List
        extend self
        extend Helper

        def analyze(node, registry, scope, entry)
          node => AST::List(items:)

          analyze_in_parallel(items, registry, scope, entry)
            .map_node { node.with(items: it, symbol: Symbol::TypeRef['List', 'List']) }
        end
      end
    end
  end
end

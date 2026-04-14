module Jade
  module Frontend
    module SymbolResolution
      module ImplementationFunction
        extend self
        extend Helper

        def resolve(node, registry, current_entry)
          node => AST::ImplementationFunction(fn:)

          resolve_node(fn, registry, current_entry)
            .map { node.with(fn: it) }
        end
      end
    end
  end
end

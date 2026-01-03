module Jade
  module Frontend
    module SymbolResolution
      module Module
        extend self
        extend Helper

        def resolve(node, registry, current_entry)
          node => AST::Module(body:)

          resolve_node(body, registry, current_entry)
            .map { node.with(body: it) }
        end
      end
    end
  end
end

module Jade
  module Frontend
    module SymbolResolution
      module TypeDeclaration
        extend self
        extend Helper

        def resolve(node, registry, current_entry)
          node => AST::TypeDeclaration(name:, variants:)

          symbol = current_entry
            .lookup_type(name)
            .to_ref

          variants
            .map { resolve_node(it, registry, current_entry) }
            .then { Result.sequence(it) }
            .map { node.with(symbol:, variants: it) }
        end
      end
    end
  end
end

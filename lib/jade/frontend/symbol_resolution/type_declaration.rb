module Jade
  module Frontend
    module SymbolResolution
      module TypeDeclaration
        extend self

        def resolve(node, registry, current_entry)
          node => AST::TypeDeclaration(name:, variants:)

          symbol = current_entry
            .lookup_type(name)
            .to_ref

          variants
            .map { SymbolResolution.resolve(it, registry, current_entry) }
            .then { node.with(symbol:, variants: it) }
        end
      end
    end
  end
end

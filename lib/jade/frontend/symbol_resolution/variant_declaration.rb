module Jade
  module Frontend
    module SymbolResolution
      module VariantDeclaration
        extend self

        def resolve(node, registry, current_entry)
          node => AST::VariantDeclaration(name:)

          current_entry
            .lookup_value(name)
            .to_ref
            .then { node.with(symbol: it) }
        end
      end
    end
  end
end

module Jade
  module Frontend
    module SymbolResolution
      module StructDeclaration
        extend self
        extend Helper

        def resolve(node, registry, current_entry)
          node => AST::StructDeclaration(name:)

          current_entry
            .lookup_type(name)
            .to_ref
            .then { node.with(symbol: it) }
            .then { Result[it, []]}
        end
      end
    end
  end
end

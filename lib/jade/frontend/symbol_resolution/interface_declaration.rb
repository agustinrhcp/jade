module Jade
  module Frontend
    module SymbolResolution
      module InterfaceDeclaration
        extend self
        extend Helper

        def resolve(node, _registry, current_entry)
          node => AST::InterfaceDeclaration(name:)

          current_entry
            .lookup_type(name)
            .to_ref
            .then { node.with(symbol: it) }
            .then { Result[it, []] }
        end
      end
    end
  end
end

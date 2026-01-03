module Jade
  module Frontend
    module SymbolResolution
      module FunctionDeclaration
        extend self

        def resolve(node, registry, current_entry)
          node => AST::FunctionDeclaration(name:, body:)

          symbol = current_entry
            .lookup_value(name)
            .to_ref

          SymbolResolution.resolve(body, registry, current_entry)
            .then { node.with(body: it, symbol:) }
        end
      end
    end
  end
end

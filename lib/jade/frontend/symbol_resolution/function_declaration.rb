module Jade
  module Frontend
    module SymbolResolution
      module FunctionDeclaration
        extend self
        extend Helper

        def resolve(node, registry, current_entry)
          node => AST::FunctionDeclaration(name:, body:)

          symbol = current_entry
            .lookup_value(name)
            .to_ref

          resolve_node(body, registry, current_entry)
            .map { node.with(body: it, symbol:) }
        end
      end
    end
  end
end

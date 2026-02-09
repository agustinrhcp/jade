module Jade
  module Frontend
    module SymbolResolution
      module FunctionDeclaration
        extend self
        extend Helper

        def resolve(node, registry, current_entry)
          node => AST::FunctionDeclaration(name:, body:)

          fn_symbol = current_entry.lookup_value(name)

          resolve_node(body, registry, current_entry)
            .map do
              node.with(
                body: it,
                symbol: fn_symbol.to_ref,
              )
            end
        end
      end
    end
  end
end

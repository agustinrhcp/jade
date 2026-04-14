module Jade
  module Frontend
    module SymbolResolution
      module Implementation
        extend self
        extend Helper

        def resolve(node, registry, current_entry)
          node => AST::Implementation(interface:, applied_type:, functions:)

          interface_ref = current_entry.lookup_type(interface).to_ref
          type_ref      = current_entry.lookup_type(applied_type.constructor.type).to_ref

          impl_symbol = current_entry
            .implementations[[
              interface_ref.qualified_name,
              type_ref.qualified_name,
            ]]

          functions
            .map { resolve_node(it, registry, current_entry) }
            .then { Result.sequence(it) }
            .map { node.with(symbol: impl_symbol, functions: it) }
        end
      end
    end
  end
end

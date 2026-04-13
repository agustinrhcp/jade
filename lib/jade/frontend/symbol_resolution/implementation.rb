module Jade
  module Frontend
    module SymbolResolution
      module Implementation
        extend self

        def resolve(node, _registry, current_entry)
          node => AST::Implementation(interface:, constructor:)

          interface_ref = current_entry.lookup_type(interface).to_ref
          type_ref      = current_entry.lookup_type(constructor).to_ref

          current_entry
            .implementations[[
              interface_ref.qualified_name,
              type_ref.qualified_name,
            ]]
            .then { Result[node.with(symbol: it), []] }
        end
      end
    end
  end
end

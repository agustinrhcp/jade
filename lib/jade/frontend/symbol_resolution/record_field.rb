module Jade
  module Frontend
    module SymbolResolution
      module RecordField
        extend self
        extend Helper

        def resolve(node, registry, current_entry)
          node => AST::RecordField(value:)

          resolve_node(value, registry, current_entry)
            .map { node.with(value: it) }
        end
      end
    end
  end
end

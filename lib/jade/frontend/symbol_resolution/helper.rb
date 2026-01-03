module Jade
  module Frontend
    module SymbolResolution
      module Helper
        extend self

        def resolve_node(node, registry, current_entry)
          SymbolResolution.resolve_node(node, registry, current_entry)
        end
      end
    end
  end
end

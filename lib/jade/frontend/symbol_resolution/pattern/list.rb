module Jade
  module Frontend
    module SymbolResolution
      module Pattern
        module List
          extend self
          extend Helper

          def resolve(node, registry, current_entry)
            node => AST::Pattern::List(patterns:)

            patterns
              .map { resolve_node(it, registry, current_entry) }
              .then { Result.sequence(it) }
              .map { node.with(patterns: it) }
          end
        end
      end
    end
  end
end

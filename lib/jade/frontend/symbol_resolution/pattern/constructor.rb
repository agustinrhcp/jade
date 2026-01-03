module Jade
  module Frontend
    module SymbolResolution
      module Pattern
        module Constructor
          extend self

          def resolve(node, registry, current_entry)
            node => AST::Pattern::Constructor(constructor:, patterns:)

            symbol = current_entry
              .lookup_value(constructor)
              .to_ref

            patterns
              .map { SymbolResolution.resolve(it, registry, current_entry) }
              .then { node.with(patterns: it, symbol:) }
          end
        end
      end
    end
  end
end

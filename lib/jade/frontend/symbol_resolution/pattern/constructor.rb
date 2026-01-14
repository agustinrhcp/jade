module Jade
  module Frontend
    module SymbolResolution
      module Pattern
        module Constructor
          extend self
          extend Helper

          def resolve(node, registry, current_entry)
            node => AST::Pattern::Constructor(constructor:, patterns:)

            resolve_node(constructor, registry, current_entry) => {
              node: const_resolved, errors: const_errors,
            }

            patterns
              .map { resolve_node(it, registry, current_entry) }
              .then { Result.sequence(it) }
              .map { node.with(patterns: it) }
              .map { it.with(symbol: const_resolved.symbol&.to_ref) }
              .map { it.with(constructor: const_resolved) }
              .add_errors(const_errors)
          end
        end
      end
    end
  end
end

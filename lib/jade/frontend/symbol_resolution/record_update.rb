module Jade
  module Frontend
    module SymbolResolution
      module RecordUpdate
        extend self
        extend Helper

        def resolve(node, registry, current_entry)
          node => AST::RecordUpdate(fields:, base:)

          resolve_node(base, registry, current_entry) => {
            node: base_resolved, errors: base_errors,
          }

          fields
            .map { resolve_node(it, registry, current_entry) }
            .then { Result.sequence(it) }
            .map { node.with(fields: it, base: base_resolved) }
            .add_errors(base_errors)
        end
      end
    end
  end
end

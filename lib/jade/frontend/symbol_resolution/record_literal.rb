module Jade
  module Frontend
    module SymbolResolution
      module RecordLiteral
        extend self
        extend Helper

        def resolve(node, registry, current_entry)
          node => AST::RecordLiteral(fields:)

          symbol = Symbol.anonymous_record(fields.map(&:key))

          fields
            .map { resolve_node(it, registry, current_entry) }
            .then { Result.sequence(it) }
            .map { node.with(fields: it, symbol:) }
        end
      end
    end
  end
end

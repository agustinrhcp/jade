module Jade
  module Frontend
    module SymbolResolution
      module Pattern
        module Record
          extend self
          extend Helper

          def resolve(node, registry, current_entry)
            node => AST::Pattern::Record(fields:)

            symbol = Symbol.anonymous_record(fields.map(&:name), Symbol.var('a', nil))
            
            fields
              .map { resolve_node(it.pattern, registry, current_entry) }
              .then { Result.sequence(it) }
              .map { node.with(fields: fields.zip(it).map { |f, p| f.with(pattern: p) }) }
              .map { it.with(symbol:) }
          end
        end
      end
    end
  end
end

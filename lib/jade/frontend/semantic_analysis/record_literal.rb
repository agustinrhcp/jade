module Jade
  module Frontend
    module SemanticAnalysis
      module RecordLiteral
        extend self
        extend Helper

        def analyze(node, registry, scope, entry)
          node => AST::RecordLiteral(fields:)

          Result
            .combine(node, scope:,
              fields: analyze_in_parallel(fields, registry, scope, entry),
            )
            .map_node { it.with(symbol: Symbol.anonymous_record(fields.map(&:key))) }
            .add_errors(analyze_duplicate_fields(fields, entry))
        end
      end
    end
  end
end

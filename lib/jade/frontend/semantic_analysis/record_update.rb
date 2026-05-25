module Jade
  module Frontend
    module SemanticAnalysis
      module RecordUpdate
        extend self
        extend Helper

        def analyze(node, registry, scope, entry)
          node => AST::RecordUpdate(base:, fields:)

          Result
            .combine(node, scope:,
              base: analyze_node(base, registry, scope, entry),
              fields: analyze_in_parallel(fields, registry, scope, entry),
            )
            .add_errors(analyze_duplicate_fields(fields, entry))
        end
      end
    end
  end
end

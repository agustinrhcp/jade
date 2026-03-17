module Jade
  module Frontend
    module SemanticAnalysis
      module RecordUpdate
        extend self
        extend Helper

        def analyze(node, registry, scope, entry)
          node => AST::RecordUpdate(base:, fields:)

          analyze_node(base, registry, scope, entry) => { errors: base_errors }

          analyze_many(fields, registry, scope, entry)
            .add_errors(analyze_duplicate_fields(fields, entry))
            .add_errors(base_errors)
        end
      end
    end
  end
end

module Jade
  module Frontend
    module SemanticAnalysis
      module RecordLiteral
        extend self
        extend Helper

        def analyze(node, registry, scope, entry)
          node => AST::RecordLiteral(fields:)

          analyze_many(fields, registry, scope, entry)
            .add_errors(analyze_duplicate_fields(fields, entry))
        end
      end
    end
  end
end

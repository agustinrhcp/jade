module Jade
  module Frontend
    module SemanticAnalysis
      module TypeDeclaration
        extend self
        extend Helper

        def analyze(node, registry, scope)
          node => AST::TypeDeclaration(symbol:)

          annotation_errors = validate_type_symbol(symbol, registry)

          SemanticAnalyzer::Result[scope, annotation_errors]
        end
      end
    end
  end
end

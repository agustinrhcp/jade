module Jade
  module Frontend
    module SemanticAnalysis
      module InteropImportDeclaration
        extend self
        extend Helper

        def analyze(node, registry, scope)
          node => AST::InteropImportDeclaration(functions:)

          annotation_errors = functions
            .flat_map { validate_type_symbol(it.symbol, registry) }

          SemanticAnalyzer::Result[scope, annotation_errors]
        end
      end
    end
  end
end

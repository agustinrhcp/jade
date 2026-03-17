module Jade
  module Frontend
    module SemanticAnalysis
      module InteropImportDeclaration
        extend self
        extend Helper

        def analyze(node, registry, scope, entry)
          node => AST::InteropImportDeclaration(functions:)

          functions
            .flat_map { validate_type_symbol(it.symbol, registry) }
            .then { Result[scope, it] }
        end
      end
    end
  end
end

module Jade
  module Frontend
    module SemanticAnalysis
      module VariantDeclaration
        extend self
        extend Helper

        def analyze(node, _registry, scope, entry)
          node => AST::VariantDeclaration(name:)

          node
            .with(symbol: entry.lookup_value(name).to_ref)
            .then { Result.init(it, scope) }
        end
      end
    end
  end
end

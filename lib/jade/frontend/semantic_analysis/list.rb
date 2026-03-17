module Jade
  module Frontend
    module SemanticAnalysis
      module List
        extend self
        extend Helper

        def analyze(node, registry, scope, entry)
          node => AST::List(items:)

          analyze_many(items, registry, scope, entry)
            .with(scope:)
        end
      end
    end
  end
end

module Jade
  module Frontend
    module SemanticAnalysis
      module Body
        extend self
        extend Helper

        def analyze(node, registry, scope, entry)
          node => AST::Body(expressions:)

          analyze_many(expressions, registry, scope, entry)
        end
      end
    end
  end
end

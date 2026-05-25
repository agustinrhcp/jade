module Jade
  module Frontend
    module SemanticAnalysis
      module ImplementationFunction
        extend self
        extend Helper

        def analyze(node, registry, scope, entry)
          node => AST::ImplementationFunction(fn:)

          Result.combine(node, scope:, fn: analyze_node(fn, registry, scope, entry))
        end
      end
    end
  end
end

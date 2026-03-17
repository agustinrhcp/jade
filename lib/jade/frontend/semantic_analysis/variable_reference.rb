module Jade
  module Frontend
    module SemanticAnalysis
      module VariableReference
        extend self
        extend Helper

        def analyze(node, registry, scope, entry)
          node => AST::VariableReference(name:)

          lookup(scope, name, entry, node.range)
        end
      end
    end
  end
end

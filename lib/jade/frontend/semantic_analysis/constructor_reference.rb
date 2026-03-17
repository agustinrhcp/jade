module Jade
  module Frontend
    module SemanticAnalysis
      module ConstructorReference
        extend self
        extend Helper

        def analyze(node, registry, scope, entry)
          node => AST::ConstructorReference(name:)

          lookup(scope, name, entry, node.range)
        end
      end
    end
  end
end

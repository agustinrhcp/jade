module Jade
  module Frontend
    module SemanticAnalysis
      module ConstructorReference
        extend self
        extend Helper

        def analyze(node, registry, scope, entry)
          node => AST::ConstructorReference(name:)

          return Result[scope, []] if Stdlib.private_constructor?(name)

          lookup(scope, name, entry, node.range)
        end
      end
    end
  end
end

module Jade
  module Frontend
    module SemanticAnalysis
      module PatternBinding
        extend self
        extend Helper

        def analyze(node, registry, scope, entry)
          node => AST::Pattern::Binding(name:)

          bind(scope, Symbol.var(name, node.range), entry)
        end
      end
    end
  end
end

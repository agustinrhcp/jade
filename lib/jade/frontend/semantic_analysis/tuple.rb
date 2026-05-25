module Jade
  module Frontend
    module SemanticAnalysis
      module Tuple
        extend self
        extend Helper

        def analyze(node, registry, scope, entry)
          node => AST::Tuple(items:)

          analyze_in_sequence(items, registry, scope, entry)
            .with(scope:)
        end
      end
    end
  end
end

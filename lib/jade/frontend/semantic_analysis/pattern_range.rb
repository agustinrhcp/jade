module Jade
  module Frontend
    module SemanticAnalysis
      module PatternRange
        extend self
        extend Helper

        # Both bounds are integer literals, so there is no name to resolve and
        # nothing to bind.
        def analyze(node, _registry, scope, _entry)
          Result.init(node, scope)
        end
      end
    end
  end
end

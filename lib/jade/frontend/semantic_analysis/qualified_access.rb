module Jade
  module Frontend
    module SemanticAnalysis
      module QualifiedAccess
        extend self
        extend Helper

        def analyze(node, _registry, scope, _entry)
          Result.init(node, scope)
        end
      end
    end
  end
end

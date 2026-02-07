module Jade
  module Frontend
    module SemanticAnalysis
      module Helper
        def analyze_node(node, registry, scope)
          SemanticAnalyzer.send(:analyze_r, node, registry, scope)
        end

        def bind(scope, name, symbol)
          if scope.lookup(name)
            SemanticAnalyzer::Result[scope, [ShadowingError.new(name)]]

          else
            SemanticAnalyzer::Result[scope.bind(name, symbol), []]
          end
        end

        def lookup(scope, name)
          if scope.lookup(name)
            SemanticAnalyzer::Result[scope, []]
          else
            UndefinedVariable.new(name)
              .then { Result[scope, [it]] }
          end
        end
      end
    end
  end
end

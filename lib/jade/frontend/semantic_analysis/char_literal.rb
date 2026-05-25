module Jade
  module Frontend
    module SemanticAnalysis
      module CharLiteral
        extend self
        extend Helper

        def analyze(node, _registry, scope, _entry)
          Result.init(node.with(symbol: Symbol::TypeRef['Char', 'Char']), scope)
        end
      end
    end
  end
end

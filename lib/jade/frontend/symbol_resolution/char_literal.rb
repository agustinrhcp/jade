module Jade
  module Frontend
    module SymbolResolution
      module CharLiteral
        extend self

        def resolve(node, _, _)
          node.with(symbol: Symbol::TypeRef['Char', 'Char'])
            .then { Result[it, []] }
        end
      end
    end
  end
end

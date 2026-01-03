module Jade
  module Frontend
    module SymbolResolution
      module ImportDeclaration
        extend self

        def resolve(node, _, _)
          Result[node, []]
        end
      end
    end
  end
end

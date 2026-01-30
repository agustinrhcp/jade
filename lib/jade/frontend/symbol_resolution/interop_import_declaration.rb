module Jade
  module Frontend
    module SymbolResolution
      module InteropImportDeclaration
        extend self

        def resolve(node, _, _)
          Result[node, []]
        end
      end
    end
  end
end

module Jade
  module Frontend
    module SymbolResolution
      module QualifiedAccess
        extend self

        def resolve(node, _, _)
          Result[node, []]
        end
      end
    end
  end
end

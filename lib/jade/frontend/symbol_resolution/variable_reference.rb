module Jade
  module Frontend
    module SymbolResolution
      module VariableReference
        extend self

        def resolve(node, _, _)
          Result[node, []]
        end
      end
    end
  end
end

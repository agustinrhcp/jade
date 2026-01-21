module Jade
  module Frontend
    module SymbolResolution
      module VariableReference
        extend self

        def resolve(node, registry, current_entry)
          symbol = if current_entry.values[node.name]
            current_entry.values[node.name]
          else
            Symbol.var(node.name)
          end

          Result[node.with(symbol:), []]
        end
      end
    end
  end
end

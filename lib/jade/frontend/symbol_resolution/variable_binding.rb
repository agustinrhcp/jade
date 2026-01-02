module Jade
  module Frontend
    module SymbolResolution
      module VariableBinding
        extend self

        def resolve(node, registry, current_entry)
          node => AST::VariableBinding(expression:)

          SymbolResolution
            .resolve(expression, registry, current_entry)
            .then { node.with(expression: it) }
        end
      end
    end
  end
end

module Jade
  module Frontend
    module SymbolResolution
      module Body
        extend self

        def resolve(node, registry, current_entry)
          node => AST::Body(expressions:)

          expressions
            .map { SymbolResolution.resolve(it, registry, current_entry) }
            .then { node.with(expressions: it) }
        end
      end
    end
  end
end

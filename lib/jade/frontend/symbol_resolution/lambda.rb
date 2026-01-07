module Jade
  module Frontend
    module SymbolResolution
      module Lambda
        extend self
        extend Helper

        def resolve(node, registry, current_entry)
          node => AST::Lambda(params:, body:)

          symbol = Symbol::Lambda[params.size]

          resolve_node(body, registry, current_entry)
            .map { node.with(body: it, symbol:) }
        end
      end
    end
  end
end

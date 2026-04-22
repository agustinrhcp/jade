module Jade
  module Frontend
    module SymbolResolution
      module Lambda
        extend self
        extend Helper

        def resolve(node, registry, current_entry)
          node => AST::Lambda(params:, body:)

          symbol = Symbol::Lambda[params.size]

          resolve_node(body, registry, current_entry) => {
            node: body_resolved, errors: body_errors,
          }

          params
            .map { resolve_node(it, registry, current_entry) }
            .then { Result.sequence(it) }
            .map { node.with(params: it, body: body_resolved, symbol:) }
            .add_errors(body_errors)
        end
      end
    end
  end
end

module Jade
  module Frontend
    module SymbolResolution
      module FunctionCall
        extend self
        extend Helper

        def resolve(node, registry, current_entry)
          node => AST::FunctionCall(callee:, args:)

          resolve_node(callee, registry, current_entry) => {
            node: callee_resolved, errors: callee_errors,
          }

          args
            .map { resolve_node(it, registry, current_entry) }
            .then { Result.sequence(it) }
            .map { node.with(args: it, callee: callee_resolved) }
            .add_errors(callee_errors)
        end
      end
    end
  end
end

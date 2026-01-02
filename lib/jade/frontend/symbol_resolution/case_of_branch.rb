module Jade
  module Frontend
    module SymbolResolution
      module CaseOfBranch
        extend self
        extend Helper

        def resolve(node, registry, current_entry)
          node => AST::CaseOfBranch(pattern:, body:)

          resolve_node(body, registry, current_entry) => {
            node: body_resolved, errors: body_errors,
          }

          resolve_node(pattern, registry, current_entry)
            .map { node.with(pattern: it, body: body_resolved ) }
            .add_errors(body_errors)
        end
      end
    end
  end
end

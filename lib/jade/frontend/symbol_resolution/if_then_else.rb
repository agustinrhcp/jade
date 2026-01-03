module Jade
  module Frontend
    module SymbolResolution
      module IfThenElse
        extend self
        extend Helper

        def resolve(node, registry, current_entry)
          node => AST::IfThenElse(condition:, if_branch:, else_branch:)

          [
            resolve_node(condition, registry, current_entry),
            resolve_node(if_branch, registry, current_entry),
            resolve_node(else_branch, registry, current_entry),
          ]
            .then { Result.sequence(it) }
            .map { |(c, i, e)| node.with(condition: c, if_branch: i, else_branch: e) }
        end
      end
    end
  end
end

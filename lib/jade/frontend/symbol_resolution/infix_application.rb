module Jade
  module Frontend
    module SymbolResolution
      module InfixApplication
        extend self
        extend Helper

        def resolve(node, registry, current_entry)
          node => AST::InfixApplication(left:, operator:, right:)

          #  TODO: Fail if operator isn't present
          symbol = current_entry
            .lookup_value("(#{operator.value})")
            .to_ref

          resolve_node(left, registry, current_entry) => {
            node: left_resolved, errors: left_errors,
          }

          resolve_node(right, registry, current_entry)
            .map { node.with(right: it, left: left_resolved, operator: operator.with(symbol:)) }
            .add_errors(left_errors)
        end
      end
    end
  end
end

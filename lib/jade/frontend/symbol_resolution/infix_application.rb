module Jade
  module Frontend
    module SymbolResolution
      module InfixApplication
        extend self

        def resolve(node, registry, current_entry)
          node => AST::InfixApplication(left:, operator:, right:)

          symbol = current_entry
            .lookup_value("(#{operator.value})")
            .to_ref

          node
            .with(left: SymbolResolution.resolve(left, registry, current_entry))
            .with(right: SymbolResolution.resolve(right, registry, current_entry))
            .with(operator: operator.with(symbol:))
        end
      end
    end
  end
end

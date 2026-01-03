module Jade
  module Frontend
    module SymbolResolution
      module IfThenElse
        extend self

        def resolve(node, registry, current_entry)
          node => AST::IfThenElse(condition:, if_branch:, else_branch:)

          node
            .with(condition: SymbolResolution.resolve(condition, registry, current_entry))
            .with(if_branch: SymbolResolution.resolve(if_branch, registry, current_entry))
            .with(else_branch: SymbolResolution.resolve(else_branch, registry, current_entry))
        end
      end
    end
  end
end

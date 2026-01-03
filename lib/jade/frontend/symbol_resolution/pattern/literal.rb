module Jade
  module Frontend
    module SymbolResolution
      module Pattern
        module Literal
          extend self

          def resolve(node, registry, current_entry)
            node => AST::Pattern::Literal(literal:)

            SymbolResolution.resolve(literal, registry, current_entry)
              .then { node.with(literal: it) }
          end
        end
      end
    end
  end
end

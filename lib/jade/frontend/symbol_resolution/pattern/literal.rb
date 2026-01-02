module Jade
  module Frontend
    module SymbolResolution
      module Pattern
        module Literal
          extend self
          extend Helper

          def resolve(node, registry, current_entry)
            node => AST::Pattern::Literal(literal:)

            resolve_node(literal, registry, current_entry)
              .map { node.with(literal: it) }
          end
        end
      end
    end
  end
end

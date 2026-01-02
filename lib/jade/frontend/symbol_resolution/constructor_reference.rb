module Jade
  module Frontend
    module SymbolResolution
      module ConstructorReference
        extend self

        def resolve(node, registry, current_entry)
          node => AST::ConstructorReference(name:)

          case current_entry.lookup_value(name)
          in nil
            Error::ConstructorNotFound
              .new(current_entry.name, node.range, name:)
              .then { Result[node, [it]] }

          in symbol
            symbol.to_ref
              .then { node.with(symbol: it) }
              .then { Result[it, []] }
          end
        end
      end
    end
  end
end

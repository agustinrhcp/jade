module Jade
  module Frontend
    module SymbolResolution
      module ConstructorReference
        extend self

        def resolve(node, registry, current_entry)
          node => AST::ConstructorReference(name:)

          symbol = current_entry.lookup_value(name) ||
            resolve_private_constructor(name, registry)

          case symbol
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

        private

        def resolve_private_constructor(name, registry)
          if Stdlib.private_constructor?(name)
            registry.lookup(Symbol::ValueRef.new(*name.split('.')))
          end
        end
      end
    end
  end
end

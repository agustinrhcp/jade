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
              .new(
                current_entry.name,
                node.range,
                name:,
                exposed_type_module: exposed_type_origin(name, current_entry, registry),
              )
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

        def exposed_type_origin(name, current_entry, registry)
          type_ref = current_entry.imported_types[name]
          return nil unless type_ref

          entry = registry.get(type_ref.module_name)
          return nil if entry.nil? || Stdlib.is_stdlib?(entry)

          type_ref.module_name
        end
      end
    end
  end
end

module Jade
  module Frontend
    module SemanticAnalysis
      module ConstructorReference
        extend self
        extend Helper

        def analyze(node, registry, scope, entry)
          node => AST::ConstructorReference(name:)

          symbol = scope.lookup(name) || resolve_private_constructor(name, registry)

          case symbol
          in nil
            (tuple_arity_overflow(name, entry, node.range) ||
              Error::ConstructorNotFound.new(
                entry.name,
                node.range,
                name:,
                exposed_type_module: exposed_type_origin(name, entry, registry),
                candidates: scope.bindings.keys.select { it.match?(/\A[A-Z]/) },
              ))
              .then do
                Result
                  .init(node, scope)
                  .add_errors([it])
              end

          in symbol
            Result.init(node.with(symbol: symbol.to_ref), scope)
          end
        end

        private

        def resolve_private_constructor(name, registry)
          if Stdlib.private_constructor?(name)
            registry.lookup(Symbol::ValueRef.new(*name.split('.')))
          end
        end

        def tuple_arity_overflow(name, entry, span)
          klass = ForwardDeclaration::Error::TupleArityOverflow

          name
            .match(/^Tuple\.Tuple(?<arity>\d+)$/)
            &.then { it[:arity].to_i }
            &.then { it > klass::MAX_ARITY ? it : nil }
            &.then { klass.new(entry.name, span, arity: it) }
        end

        def exposed_type_origin(name, entry, registry)
          type_ref = entry.imported_types[name]
          return nil unless type_ref

          target_entry = registry.get(type_ref.module_name)
          return nil if target_entry.nil? || Stdlib.is_stdlib?(target_entry)

          type_ref.module_name
        end
      end
    end
  end
end

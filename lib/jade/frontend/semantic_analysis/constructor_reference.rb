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
                hint: constructor_hint(name, entry, registry),
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

        # An imported module owning a constructor by this name is the whole
        # story: either it keeps its constructors private, or it exposes them
        # and the import here asked for the type alone.
        def constructor_hint(name, entry, registry)
          entry
            .imports
            .filter_map { hint_for(it.module_name, name, registry) }
            .first
        end

        def hint_for(module_name, name, registry)
          target = registry.get(module_name)
          return nil if target.nil? || Stdlib.is_stdlib?(target)

          type_name = owning_type(target, name)
          return nil unless type_name && target.exposed_type(type_name)

          exposes_constructor?(target, type_name, name)
            .then { it ? :import : :expose }
            .then { Error::ConstructorNotFound::Hint[module_name, type_name, it] }
        end

        def owning_type(target, name)
          target
            .defined_types
            .find { |_, sym| sym.constructor_refs.any? { it.name == name } }
            &.first
        end

        def exposes_constructor?(target, type_name, name)
          target
            .exposed_type_variants(type_name)
            .to_a
            .any? { it.name == name }
        end
      end
    end
  end
end

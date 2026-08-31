module Jade
  module Frontend
    module SemanticAnalysis
      module TypeAliasDeclaration
        extend self
        extend Helper

        def analyze(node, registry, scope, entry)
          node => AST::TypeAliasDeclaration(name:)

          symbol_ref = entry.lookup_type(name).to_ref

          Result
            .init(node.with(symbol: symbol_ref), scope)
            .add_errors(validate_no_unbound_vars(symbol_ref, registry, entry))
            .add_errors(validate_type_symbol(symbol_ref, registry, entry))
            .add_errors(validate_no_cycle(symbol_ref, registry, entry))
        end

        private

        def validate_no_unbound_vars(symbol_ref, registry, entry)
          actual_symbol = registry.lookup(symbol_ref)
          return [] unless actual_symbol.body

          missing = collect_vars(actual_symbol.body, registry)
            .group_by(&:name)
            .reject { |name, _| actual_symbol.type_params.map(&:name).include?(name) }
            .values
            .flatten

          return [] if missing.empty?

          [
            Error::UnboundTypeVariable.new(
              entry.name,
              missing.size == 1 ? missing.first.decl_span : actual_symbol.decl_span,
              type_name: symbol_ref.name,
              variables: missing.map(&:name).uniq,
            ),
          ]
        end

        def validate_no_cycle(symbol_ref, registry, entry)
          actual_symbol = registry.lookup(symbol_ref)
          return [] unless actual_symbol.body

          qname = actual_symbol.qualified_name

          cycle = find_cycle(qname, actual_symbol.body, registry, [qname], ::Set[])
          return [] unless cycle

          [
            Error::RecursiveTypeAlias.new(
              entry.name,
              actual_symbol.decl_span,
              name: symbol_ref.name,
              cycle: cycle.map { Symbol.unqualified_name(it) },
            ),
          ]
        end

        # Returns the qname-path back to `start_qname` if found, nil otherwise.
        # Whether an alias reaches `start_qname` does not depend on the path
        # taken to it, so `explored` is shared across the whole walk and an
        # alias that came up clean once is never walked again. Without it an
        # alias naming another one twice doubles the work per level.
        def find_cycle(start_qname, sym, registry, visited, explored)
          case sym
          in Symbol::TypeRef
            resolved = registry.lookup(sym)
            return nil unless resolved.is_a?(Symbol::Alias)

            qname = resolved.qualified_name
            return visited + [qname] if qname == start_qname
            return nil unless explored.add?(qname)

            resolved.body &&
              find_cycle(start_qname, resolved.body, registry, visited + [qname], explored)

          in Symbol::TypeApplication(constructor:, args:)
            first_cycle(start_qname, [constructor, *args], registry, visited, explored)

          in Symbol::PartialApplication(constructor:, args:)
            first_cycle(start_qname, [constructor, *args], registry, visited, explored)

          in Symbol::FunctionType(params:, return_type:)
            first_cycle(start_qname, params + [return_type], registry, visited, explored)

          in Symbol::RecordType(fields:)
            first_cycle(start_qname, fields.values, registry, visited, explored)

          # Leaves (Variable, primitives, etc.) — can't transitively
          # contain an alias reference, so no cycle through them.
          else
            nil
          end
        end

        def first_cycle(start_qname, syms, registry, visited, explored)
          syms
            .lazy
            .filter_map { find_cycle(start_qname, it, registry, visited, explored) }
            .first
        end
      end
    end
  end
end

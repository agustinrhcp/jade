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

          cycle = find_cycle(actual_symbol.qualified_name, actual_symbol.body, registry, [actual_symbol.qualified_name])
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
        def find_cycle(start_qname, sym, registry, visited)
          case sym
          in Symbol::TypeRef
            resolved = registry.lookup(sym)
            return nil unless resolved.is_a?(Symbol::Alias)

            qname = resolved.qualified_name
            return visited + [qname] if qname == start_qname
            return nil if visited.include?(qname)

            resolved.body && find_cycle(start_qname, resolved.body, registry, visited + [qname])

          in Symbol::TypeApplication(constructor:, args:)
            first_cycle(start_qname, [constructor, *args], registry, visited)

          in Symbol::PartialApplication(constructor:, args:)
            first_cycle(start_qname, [constructor, *args], registry, visited)

          in Symbol::FunctionType(params:, return_type:)
            first_cycle(start_qname, params + [return_type], registry, visited)

          in Symbol::RecordType(fields:)
            first_cycle(start_qname, fields.values, registry, visited)

          # Leaves (Variable, primitives, etc.) — can't transitively
          # contain an alias reference, so no cycle through them.
          else
            nil
          end
        end

        def first_cycle(start_qname, syms, registry, visited)
          syms.each do |s|
            c = find_cycle(start_qname, s, registry, visited)
            return c if c
          end
          nil
        end
      end
    end
  end
end

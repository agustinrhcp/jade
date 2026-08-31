module Jade
  module Frontend
    module SemanticAnalysis
      module TypeAliasDeclaration
        # An alias is replaced by its body, so one that reaches itself would
        # expand forever. This finds the path back, or nothing.
        module CycleDetection
          extend self

          def call(symbol_ref, registry, entry)
            symbol = registry.lookup(symbol_ref)
            return [] unless symbol.body

            qname = symbol.qualified_name
            cycle = find(qname, symbol.body, registry, [qname], ::Set[])

            return [] unless cycle
            return [] unless reports_for?(qname, cycle, registry)

            [
              Error::RecursiveTypeAlias.new(
                entry.name,
                symbol.decl_span,
                name: symbol_ref.name,
                cycle: cycle.map { Symbol.unqualified_name(it) },
              ),
            ]
          end

          private

          # Every alias in a cycle finds it, so `A = B, B = A` would be
          # reported twice for one mistake. The first by declaration reports
          # and the rest stay quiet, which needs no state shared between
          # declarations since each walk already knows the whole cycle.
          def reports_for?(qname, cycle, registry)
            qname == cycle.min_by { declaration_order(it, registry) }
          end

          def declaration_order(qname, registry)
            Symbol
              .type_ref_from_qualified_name(qname)
              .then { registry.lookup(it) }
              .then { [it.decl_span&.begin || 0, qname] }
          end

          # Returns the qname-path back to `start_qname` if found, nil
          # otherwise. Whether an alias reaches `start_qname` does not depend
          # on the path taken to it, so `explored` is shared across the whole
          # walk and an alias that came up clean once is never walked again.
          # Without it an alias naming another one twice doubles the work per
          # level.
          def find(start_qname, sym, registry, visited, explored)
            case sym
            in Symbol::TypeRef
              resolved = registry.lookup(sym)
              return nil unless resolved.is_a?(Symbol::Alias)

              qname = resolved.qualified_name
              return visited + [qname] if qname == start_qname
              return nil unless explored.add?(qname)

              resolved.body &&
                find(start_qname, resolved.body, registry, visited + [qname], explored)

            in Symbol::TypeApplication(constructor:, args:)
              first(start_qname, [constructor, *args], registry, visited, explored)

            in Symbol::PartialApplication(constructor:, args:)
              first(start_qname, [constructor, *args], registry, visited, explored)

            in Symbol::FunctionType(params:, return_type:)
              first(start_qname, params + [return_type], registry, visited, explored)

            in Symbol::RecordType(fields:)
              first(start_qname, fields.values, registry, visited, explored)

            # Leaves (Variable, primitives, etc.) — can't transitively
            # contain an alias reference, so no cycle through them.
            else
              nil
            end
          end

          def first(start_qname, syms, registry, visited, explored)
            syms
              .lazy
              .filter_map { find(start_qname, it, registry, visited, explored) }
              .first
          end
        end
      end
    end
  end
end

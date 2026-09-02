module Jade
  module Frontend
    module SemanticAnalysis
      # Least fixed point over "can a value of this type be built at all".
      # A type currently being asked about counts as uninhabited, so a shape
      # that needs itself to exist bottoms out at false rather than looping.
      module Inhabitedness
        extend self

        def inhabited?(symbol, registry)
          reachable?(symbol, registry, ::Set[], {})
        end

        private

        def reachable?(sym, registry, visiting, subst)
          case sym
          in Symbol::Variable(name:)
            subst.fetch(name, true)

          in Symbol::RecordType(fields:)
            fields.values.all? { reachable?(it, registry, visiting, subst) }

          in Symbol::TypeRef
            declaration(registry.lookup(sym), [], registry, visiting)

          in Symbol::TypeApplication(constructor:, args:)
            args
              .map { reachable?(it, registry, visiting, subst) }
              .then { declaration(resolve(constructor, registry), it, registry, visiting) }

          in Symbol::Union | Symbol::Struct
            declaration(sym, [], registry, visiting)

          else
            true
          end
        end

        def resolve(constructor, registry)
          constructor.is_a?(Symbol::TypeRef) ? registry.lookup(constructor) : constructor
        end

        def declaration(head, arg_values, registry, visiting)
          return true unless head.is_a?(Symbol::Union) || head.is_a?(Symbol::Struct)

          # A declaration asked about on its own has no arguments to speak of,
          # and a parameter stands for whatever a caller supplies, so it
          # counts as something that exists.
          values = head.type_params.each_index.map { arg_values.fetch(it, true) }
          key = [head.qualified_name, values]
          return false if visiting.include?(key)

          seen = visiting + [key]
          subst = head.type_params.map(&:name).zip(values).to_h

          case head
          in Symbol::Struct(record_type:)
            record_type.nil? || reachable?(record_type, registry, seen, subst)

          in Symbol::Union(variants:) if tuple?(head)
            values.all?

          in Symbol::Union(variants:)
            variants.empty? || variants.any? { buildable?(it, registry, seen, subst) }
          end
        end

        # A tuple carries no variants to read, and unlike the other natives
        # written that way it is a product: there is no empty one to fall back
        # on the way a `List` has `[]`.
        def tuple?(head)
          head.qualified_name.start_with?('Tuple.Tuple')
        end

        def buildable?(variant_ref, registry, visiting, subst)
          registry
            .lookup(variant_ref)
            .args
            .all? { reachable?(it, registry, visiting, subst) }
        end
      end
    end
  end
end

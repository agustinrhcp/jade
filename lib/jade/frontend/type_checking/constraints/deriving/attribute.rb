module Jade
  module Frontend
    module TypeChecking
      module Constraints
        module Deriving
          # A field enum states which slot each variant fills and what it
          # holds. Both are the variant name and its payload, so both derive:
          # `Name(String)` is the column `name` carrying an encoded String.
          #
          # Derived here rather than in the app that owns the interface, for
          # the same reason as SqlMapper — the deriving framework is not
          # extensible — and inert unless an interface of exactly this shape
          # is in scope.
          module Attribute
            extend self
            include Helpers

            INTERFACE = 'Changeset.Attribute'
            STRING = 'String.String'
            VALUE = 'Decode.Value'
            FUNCTIONS = %w[name value].freeze

            def supports?(interface) = interface == INTERFACE

            def derive(constraint, registry, entry_name, &lookup)
              return failed(constraint, entry_name) unless interface_matches?(registry)

              case constraint.type
              in Type::Application(constructor: Type::Constructor(name:), args: [])
                Symbol
                  .type_ref_from_qualified_name(name)
                  .then { registry.lookup(it) }
                  .then { derive_for(constraint, it, registry, lookup, entry_name) }

              else
                failed(constraint, entry_name)
              end
            end

            private

            # Matched by name, so another project's `Changeset.Attribute`
            # would otherwise be derived against as though it were this one.
            # `name` labels the slot, `value` encodes what fills it.
            def interface_matches?(registry)
              Symbol
                .type_ref_from_qualified_name(INTERFACE)
                .then { registry.lookup(it) }
                .then do
                  it in Symbol::Interface(functions:) and
                    functions.map(&:name).sort == FUNCTIONS and
                    functions.all? { one_param?(it) } and
                    returns?(functions, 'name', STRING) and
                    returns?(functions, 'value', VALUE)
                end
            end

            def one_param?(fn)
              fn.params.size == 1
            end

            def returns?(functions, name, qualified)
              case functions.find { it.name == name }&.return_type
              in Symbol::TypeApplication(
                constructor: Symbol::TypeRef(module_name: mod, name: type_name),
                args: [],
              )
                "#{mod}.#{type_name}" == qualified

              else
                false
              end
            end

            def derive_for(constraint, symbol, registry, lookup, entry_name)
              case symbol
              in Symbol::Union if single_payload?(symbol, registry)
                derive_union(constraint, symbol, registry, lookup, entry_name)

              else
                failed(constraint, entry_name)
              end
            end

            # One slot per variant, so each variant carries exactly the value
            # that slot holds.
            def single_payload?(union_sym, registry)
              variants(union_sym, registry)
                .then { it.any? && it.all? { it.args.size == 1 } }
            end

            def derive_union(constraint, union_sym, registry, lookup, entry_name)
              vs = variants(union_sym, registry)

              vs
                .map { encodable_dep(it, registry) }
                .map { lookup.call(it) }
                .then { Results.sequence(it) }
                .map { implementation(constraint, functions(vs), deps: it) }
            end

            def encodable_dep(variant, registry)
              variant
                .args
                .first
                .then { instantiate(it, {}, registry) }
                .then { Type.constraint('Encode.Encodable', it, nil) }
            end

            def functions(variants)
              {
                'name' => derived('f', walk(variants) { |v, _| wire_name(v) }),
                'value' => derived('f', walk(variants) { |_, i| encoded(i) }),
              }
            end

            def derived(param, body)
              Symbol::DerivedFunction.new(params: [param], body:)
            end

            def walk(variants)
              variants
                .each_with_index
                .map { |v, i| [[:constructor, v.qualified_name, ['x']], [yield(v, i)]] }
                .then { [:case, [:var, 'f'], it] }
            end

            def encoded(index)
              [:call, [:impl_arg, index, 'encoder'], [[:var, 'x']]]
            end
          end
        end
      end
    end
  end
end

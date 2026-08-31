module Jade
  module Frontend
    module TypeChecking
      module Constraints
        module Deriving
          module Decodable
            extend self
            include Helpers

            INTERFACE = 'Decode.Decodable'

            def supports?(interface) = interface == INTERFACE

            # One decoder combinator per structural type, taking a decoder per
            # element. `Tuple2(a, b)` is `Decode.tuple(dec_a, dec_b)` the same
            # way `List(a)` is `Decode.list(dec_a)`.
            STRUCTURAL = {
              'List.List' => 'Decode.list',
              'Maybe.Maybe' => 'Decode.nullable',
              'Set.Set' => 'Decode.set',
              'Dict.Dict' => 'Decode.dict',
              'Tuple.Tuple2' => 'Decode.tuple',
              'Tuple.Tuple3' => 'Decode.tuple3',
              'Tuple.Tuple4' => 'Decode.tuple4',
            }.freeze

            def derive(constraint, registry, entry_name, &lookup)
              case constraint.type
              in Type::Application(constructor: Type::Constructor(name:), args:) if STRUCTURAL.key?(name)
                derive_structural(constraint, args, STRUCTURAL.fetch(name), lookup, entry_name)

              in Type::Application(constructor: Type::Constructor(name:), args:)
                resolved_sym = Symbol
                  .type_ref_from_qualified_name(name)
                  .then { registry.lookup(it) }

                case resolved_sym
                in Symbol::Struct
                  derive_struct(constraint, resolved_sym, args, registry, lookup, entry_name)

                in Symbol::Union if nullary?(resolved_sym, registry)
                  derive_nullary_union(constraint, resolved_sym, registry)

                in Symbol::Union if wrapping_variant(resolved_sym, registry)
                  derive_wrapper_peel(constraint, resolved_sym, args, registry, lookup, entry_name)

                else
                  failed(constraint, entry_name)
                end

              in Type::AnonymousRecord(fields:)
                derive_anonymous_record(constraint, fields, lookup, entry_name)

              else
                failed(constraint, entry_name)
              end
            end

            private

            def failed(constraint, entry_name)
              Err[
                Error::DerivationFailed.new(
                  entry_name,
                  constraint.origin&.range,
                  constraint:,
                  trace: [],
                )
              ]
            end

            def derive_structural(constraint, inner_types, stdlib_fn, lookup, entry_name)
              body = [:call,
                [:stdlib_fn, stdlib_fn],
                inner_types.each_index.map { [:impl_arg, it, 'decoder'] },
              ]

              inner_types
                .map { Type.constraint(INTERFACE, it, nil) }
                .map { resolve_dep(it, lookup) }
                .then { Results.sequence(it) }
                .map { implementation(constraint, body, it) }
            end

            def derive_struct(constraint, struct_sym, type_args, registry, lookup, entry_name)
              fields = struct_fields(struct_sym, type_args, registry)

              [:struct_class, struct_sym.qualified_name]
                .then { derive_record(constraint, fields, it, lookup, entry_name) }
            end

            def derive_anonymous_record(constraint, fields, lookup, entry_name)
              keys = fields.keys.map(&:to_s)

              [:anon_record_class, keys]
                .then { derive_record(constraint, fields.to_a, it, lookup, entry_name) }
            end

            # Single-variant wrapping union — decode the inner value, then wrap.
            def derive_wrapper_peel(constraint, union_sym, type_args, registry, lookup, entry_name)
              variant = registry.lookup(union_sym.variants.first)
              inner_type = instantiate(
                variant.args.first,
                union_sym.type_params.map(&:name).zip(type_args).to_h,
                registry,
              )

              dep = Type.constraint(INTERFACE, inner_type, nil)

              resolve_dep(dep, lookup).and_then do |dep_impl|
                body = [:call,
                  [:stdlib_fn, 'Decode.map'],
                  [
                    [:impl_arg, 0, 'decoder'],
                    [:struct_constructor, variant.qualified_name, 1],
                  ],
                ]

                Ok[implementation(constraint, body, [dep_impl])]
              end
            end

            def derive_record(constraint, fields, constructor_ref, lookup, entry_name)
              field_deps = fields.map do |_, field_type|
                Type.constraint(INTERFACE, field_type, nil)
              end

              field_deps
                .map { resolve_dep(it, lookup) }
                .then { Results.sequence(it) }
                .map { implementation(constraint, record_body(fields, constructor_ref), it) }
            end

            def derive_nullary_union(constraint, union_sym, registry)
              variants(union_sym, registry)
                .then { nullary_union_body(it) }
                .then { Ok[implementation(constraint, it, [])] }
            end

            def nullary_union_body(variants)
              [:call,
                [:stdlib_fn, 'Decode.string_enum'],
                [
                  [:list, variants.map { wire_name(it) }],
                  [:list, variants.map { [:call, [:struct_constructor, it.qualified_name, 0], []] }],
                ],
              ]
            end

            def record_body(fields, constructor_ref)
              [:call,
                [:stdlib_fn, 'Decode.record'],
                [
                  [:list, fields.map { |name, _| name.to_s }],
                  [:list, fields.each_index.map { [:impl_arg, it, 'decoder'] }],
                  constructor_ref,
                ],
              ]
            end

            def implementation(constraint, body, deps)
              decoder_fn = Symbol::DerivedFunction.new(params: [], body:)

              Symbol::Implementation.new(
                module_name: nil,
                interface: Symbol.type_ref_from_qualified_name(constraint.interface),
                type: constraint.type,
                type_params: [],
                constraints: [],
                functions: { 'decoder' => decoder_fn },
                deps:,
                extends: [],
                decl_span: nil,
              )
            end
          end
        end
      end
    end
  end
end

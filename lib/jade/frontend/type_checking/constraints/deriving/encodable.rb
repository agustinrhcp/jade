module Jade
  module Frontend
    module TypeChecking
      module Constraints
        module Deriving
          module Encodable
            extend self
            include Helpers

            INTERFACE = 'Encode.Encodable'

            def supports?(interface)
              interface == INTERFACE
            end

            # One encoder combinator per structural type, taking an encoder per
            # element plus the value itself. The name is what the emitted
            # encoder binds its argument to.
            STRUCTURAL = {
              'List.List' => ['Encode.list', 'items'],
              'Maybe.Maybe' => ['Encode.nullable', 'maybe'],
              'Set.Set' => ['Encode.set', 'set'],
              'Dict.Dict' => ['Encode.dict', 'dict'],
              'Tuple.Tuple2' => ['Encode.tuple', 'pair'],
              'Tuple.Tuple3' => ['Encode.tuple3', 'triple'],
              'Tuple.Tuple4' => ['Encode.tuple4', 'quad'],
            }.freeze

            def derive(constraint, registry, entry_name, &lookup)
              case constraint.type
              in Type::Application(constructor: Type::Constructor(name:), args:) if STRUCTURAL.key?(name)
                derive_structural(constraint, args, *STRUCTURAL.fetch(name), lookup, entry_name)

              in Type::Application(constructor: Type::Constructor(name:), args:)
                resolved_sym = Symbol
                  .type_ref_from_qualified_name(name)
                  .then { registry.lookup(it) }

                case resolved_sym
                in Symbol::Struct
                  derive_struct(constraint, resolved_sym, args, registry, lookup, entry_name)

                in Symbol::Union if nullary?(resolved_sym, registry)
                  derive_nullary_union(constraint, resolved_sym, registry)

                else
                  failed(constraint, entry_name)
                end

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

            def derive_structural(constraint, inner_types, stdlib_fn, param, lookup, entry_name)
              body = [:call,
                [:stdlib_fn, stdlib_fn],
                inner_types.each_index.map { [:impl_arg, it, 'encoder'] } + [[:var, param]],
              ]

              inner_types
                .map { Type.constraint(INTERFACE, it, nil) }
                .map { lookup.call(it) }
                .then { Results.sequence(it) }
                .map { implementation(constraint, params: [param], body:, deps: it) }
            end

            def derive_nullary_union(constraint, union_sym, registry)
              body = variants(union_sym, registry)
                .map { |v|
                  [
                    [:constructor, v.qualified_name, []],
                    [[:call, [:stdlib_fn, 'Encode.string'], [wire_name(v)]]],
                  ]
                }
                .then { [:case, [:var, 'v'], it] }

              Ok[implementation(constraint, params: ['v'], body:, deps: [])]
            end

            def derive_struct(constraint, struct_sym, type_args, registry, lookup, entry_name)
              fields = struct_fields(struct_sym, type_args, registry)

              field_deps = fields
                .map { |_, field_type| Type.constraint(INTERFACE, field_type, nil) }

              pair_irs = fields
                .each_with_index
                .map do |(field_name, _), idx|
                  [:call,
                    [:stdlib_fn, 'Tuple.pair'],
                    [
                      field_name.to_s,
                      [:call,
                        [:impl_arg, idx, 'encoder'],
                        [[:access, [:var, 'rec'], field_name.to_s]],
                      ],
                    ],
                  ]
                end

              body = [:call,
                [:stdlib_fn, 'Encode.object'],
                [
                  [:list, pair_irs],
                ],
              ]

              field_deps
                .map { lookup.call(it) }
                .then { Results.sequence(it) }
                .map { implementation(constraint, params: ['rec'], body:, deps: it) }
            end

            def implementation(constraint, params:, body:, deps:)
              encoder_fn = Symbol::DerivedFunction.new(params:, body:)

              Symbol::Implementation.new(
                module_name: nil,
                interface: Symbol.type_ref_from_qualified_name(constraint.interface),
                type: constraint.type,
                type_params: [],
                constraints: [],
                functions: { 'encoder' => encoder_fn },
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

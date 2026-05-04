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

            def derive(constraint, registry, entry_name, &lookup)
              case constraint.type
              in Type::Application(constructor: Type::Constructor(name: 'List.List'), args: [inner])
                derive_list(constraint, inner, lookup, entry_name)

              in Type::Application(constructor: Type::Constructor(name: 'Maybe.Maybe'), args: [inner])
                derive_nullable(constraint, inner, lookup, entry_name)

              in Type::Application(constructor: Type::Constructor(name:), args:)
                resolved_sym = Symbol
                  .type_ref_from_qualified_name(name)
                  .then { registry.lookup(it) }

                case resolved_sym
                in Symbol::Struct
                  derive_struct(constraint, resolved_sym, args, registry, lookup, entry_name)

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

            def derive_list(constraint, inner_type, lookup, entry_name)
              dep = Type.constraint(INTERFACE, inner_type, nil)

              lookup.call(dep).and_then do |dep_impl|
                body = [:call,
                  [:stdlib_fn, 'Encode.list'],
                  [
                    [:impl_arg, 0, 'encoder'],
                    [:var, 'items'],
                  ],
                ]

                Ok[implementation(constraint, params: ['items'], body:, deps: [dep_impl])]
              end
            end

            def derive_nullable(constraint, inner_type, lookup, entry_name)
              dep = Type.constraint(INTERFACE, inner_type, nil)

              lookup.call(dep).and_then do |dep_impl|
                body = [:call,
                  [:stdlib_fn, 'Encode.nullable'],
                  [
                    [:impl_arg, 0, 'encoder'],
                    [:var, 'maybe'],
                  ],
                ]

                Ok[implementation(constraint, params: ['maybe'], body:, deps: [dep_impl])]
              end
            end

            def derive_struct(constraint, struct_sym, type_args, registry, lookup, entry_name)
              fields = struct_fields(struct_sym, type_args, registry)

              field_deps = fields
                .map { |_, field_type| Type.constraint(INTERFACE, field_type, nil) }

              resolved_deps = field_deps
                .map do |dep|
                  lookup.call(dep) => Ok[impl]
                  impl
                end

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

              Ok[implementation(constraint, params: ['rec'], body:, deps: resolved_deps)]
            end

            def implementation(constraint, params:, body:, deps:)
              encoder_fn = Symbol::DerivedFunction.new(params:, body:)

              Symbol::Implementation.new(
                module_name: nil,
                interface: constraint.interface,
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

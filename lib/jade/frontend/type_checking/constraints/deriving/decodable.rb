module Jade
  module Frontend
    module TypeChecking
      module Constraints
        module Deriving
          module Decodable
            extend self

            INTERFACE = 'Decode.Decodable'

            def supports?(interface) = interface == INTERFACE

            def derive(constraint, registry, entry_name, &lookup)
              case constraint.type
              in Type::Application(constructor: Type::Constructor(name: 'List.List'), args: [inner])
                derive_unary(constraint, inner, 'Decode.list', lookup, entry_name)

              in Type::Application(constructor: Type::Constructor(name: 'Maybe.Maybe'), args: [inner])
                derive_unary(constraint, inner, 'Decode.nullable', lookup, entry_name)

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

            def derive_unary(constraint, inner_type, stdlib_fn, lookup, entry_name)
              dep = Type.constraint(INTERFACE, inner_type, nil)

              resolve_dep(dep, lookup, entry_name).and_then do |dep_impl|
                body = [:call,
                  [:stdlib_fn, stdlib_fn],
                  [
                    [:call, [:impl_arg, 0, 'decoder'], []],
                  ],
                ]

                Ok[implementation(constraint, body, [dep_impl])]
              end
            end

            def derive_struct(constraint, struct_sym, type_args, registry, lookup, entry_name)
              fields = struct_fields(struct_sym, type_args, registry)

              field_deps = fields.map do |_, field_type|
                Type.constraint(INTERFACE, field_type, nil)
              end

              resolved_deps = field_deps.map do |dep|
                resolve_dep(dep, lookup, entry_name) => Ok[impl]
                impl
              end

              constructor_ref = [:raw,
                "#{qualified_ruby(struct_sym.qualified_name)}.method(:[]).curry(#{fields.size})"
              ]
              seed = [:call, [:stdlib_fn, 'Decode.succeed'], [constructor_ref]]

              body = fields.each_with_index.reduce(seed) do |acc, ((field_name, _), idx)|
                field_decoder = [:call,
                  [:stdlib_fn, 'Decode.field'],
                  [
                    field_name.to_s,
                    [:call, [:impl_arg, idx, 'decoder'], []],
                  ],
                ]

                [:call, [:stdlib_fn, 'Decode.and_map'], [acc, field_decoder]]
              end

              Ok[implementation(constraint, body, resolved_deps)]
            end

            def struct_fields(struct_sym, type_args, registry)
              record = struct_sym.record_type
              type_param_names = struct_sym.type_params.map(&:name)
              subst = type_param_names.zip(type_args).to_h

              record.fields.map do |name, sym|
                [name, instantiate(sym, subst, registry)]
              end
            end

            def instantiate(sym, subst, registry)
              case sym
              in Symbol::Variable(name:)
                subst.fetch(name) { Type.var(nil, name) }

              in Symbol::TypeApplication(constructor:, args:)
                inner_args = args.map { instantiate(it, subst, registry) }
                Symbol
                  .type_ref(*qualify_constructor(constructor))
                  .then { registry.lookup(it) }
                  .then { type_application_to_type(it, inner_args, registry) }

              in Symbol::TypeRef
                registry
                  .lookup(sym)
                  .then { type_application_to_type(it, [], registry) }
              end
            end

            def qualify_constructor(constructor)
              [constructor.module_name, constructor.name]
            end

            def type_application_to_type(sym, args, _registry)
              case sym
              in Symbol::Union | Symbol::Struct
                Type.constructor(sym.qualified_name).apply(args)
              end
            end

            def resolve_dep(dep, lookup, entry_name)
              lookup.call(dep)
            end

            def qualified_ruby(qualified_name)
              qualified_name.gsub('.', '::')
            end

            def implementation(constraint, body, deps)
              decoder_fn = Symbol::DerivedFunction.new(params: [], body:)

              Symbol::Implementation.new(
                module_name: nil,
                interface: constraint.interface,
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

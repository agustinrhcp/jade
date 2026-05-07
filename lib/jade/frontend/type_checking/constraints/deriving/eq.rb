module Jade
  module Frontend
    module TypeChecking
      module Constraints
        module Deriving
          module Eq
            extend self
            include Helpers

            INTERFACE = 'Basics.Eq'

            def supports?(interface) = interface == INTERFACE

            def derive(constraint, registry, entry_name, &lookup)
              resolve(constraint, registry, entry_name, lookup)
            end

            private

            def resolve(constraint, registry, entry_name, lookup)
              case [constraint.interface, constraint.type]
              in [INTERFACE, Type::Application(constructor:, args:)]
                registry
                  .implementations[[constraint.interface, constructor.name]]
                  .then do
                    it \
                      ? Ok[it]
                      : derive_for_type(constraint, constructor, args, registry, lookup, entry_name)
                  end
                  .on_err { return Err[it] } => Ok(impl)

                case impl
                in Symbol::ImplementationTemplate
                  deps = dependencies_of(impl, args)
                  resolved_deps = deps.filter_map { |dep|
                    next if dep.type in Type::Var
                    lookup.call(dep) => Ok[resolved]; resolved
                  }

                  # This registers the derived function (or template)
                  #  under registry.implementations.
                  # A possible enhancement is to add it to the entry
                  #  the function is for instead. That way, for ==
                  #  we can genrate def ==. The main advantage of
                  #  this would be generated code in function calls. Instead
                  #  of a ton of lambdas, it would be just ==.call(other)
                  registry.implementations.merge!(
                    [constraint.interface, constructor.name] => impl
                  )

                  Symbol::Implementation.new(
                    module_name: nil,
                    interface: Symbol.type_ref_from_qualified_name(constraint.interface),
                    type: constraint.type,
                    type_params: args,
                    constraints: deps,
                    functions: impl.functions,
                    deps: resolved_deps,
                    extends: [],
                    decl_span: nil,
                  )

                else
                  impl
                end
                  .then { Ok[it] }

              in [INTERFACE, Type::AnonymousRecord(fields:)]
                derive_record_eq(constraint, fields, lookup)

              else
                Err[
                  Error::DerivationFailed
                    .new(entry_name, constraint.origin.range, constraint:, trace: [])
                ]
              end
            end

            def dependencies_of(impl, args)
              subst = impl
                .type_params
                .map(&:id)
                .zip(args)
                .to_h

              impl
                .constraints
                .map { it.with(type: substitute_type(it.type, subst)) }
            end

            def substitute_type(type, subst)
              case type

              in Type::Var(id:)
                subst.fetch(id, type)

              in Type::Application(constructor:, args:)
                Type::Application.new(
                  constructor: constructor,
                  args: args.map { substitute_type(it, subst) }
                )

              in Type::AnonymousRecord(fields:)
                Type::AnonymousRecord.new(
                  fields: fields.transform_values { substitute_type(it, subst) }
                )

              else
                type
              end
            end

            def derive_for_type(constraint, constructor, args, registry, lookup, entry_name)
              symbol =
                Symbol
                  .type_ref_from_qualified_name(constructor.name)
                  .then { registry.lookup(it) }

              case symbol
              in Symbol::Union
                Ok[derive_union_eq(constraint, symbol, registry, lookup)]

              in Symbol::Struct
                derive_struct_eq(constraint, symbol, args, registry, lookup, entry_name)

              else
                Err[
                  Error::DerivationFailed
                    .new(entry_name, constraint.origin.range, constraint:, trace: [])
                ]
              end
            end

            def derive_union_eq(constraint, symbol, registry, lookup)
              type_vars = symbol.type_params.map(&:name)
              index_map = type_vars.each_with_index.map.to_h

              cases = symbol.variants
                .map { registry.lookup(it) }
                .map { build_variant_case(it, index_map, lookup, constraint.origin) }

              eq_fn = Symbol::DerivedFunction.new(
                params: ["one", "other"],
                body: [:case,
                  [:list, [[:var, "one"], [:var, "other"]]],
                  cases + [[[:_], [false]]],
                ],
              )

              if type_vars.empty?
                Symbol::Implementation.new(
                  module_name: nil,
                  interface: Symbol.type_ref_from_qualified_name(constraint.interface),
                  type: constraint.type,
                  type_params: [],
                  constraints: [],
                  functions: { '(==)' => eq_fn },
                  deps: [],
                  extends: [],
                  decl_span: nil,
                )
              else
                Symbol::ImplementationTemplate.new(
                  interface: Symbol.type_ref_from_qualified_name(constraint.interface),
                  type: constraint.type,
                  type_params: type_vars.map { Type.var(it) },
                  constraints: type_vars.map {
                    Type.constraint(INTERFACE, Type.var(it), constraint.origin)
                  },
                  functions: { '(==)' => eq_fn },
                )
              end
            end

            def build_variant_case(variant, index_map, lookup, origin)
              field_count = variant.args.length

              left_vars  = (0...field_count).map { |i| "l#{i}" }
              right_vars = (0...field_count).map { |i| "r#{i}" }

              left_pattern  = [:constructor, variant.qualified_name, left_vars]
              right_pattern = [:constructor, variant.qualified_name, right_vars]

              comparisons =
                variant.args.each_with_index.map do |arg_type, i|
                  case arg_type

                  in Symbol::Variable(name:)
                    idx = index_map[name]

                    [:call,
                      [:impl_arg, idx, "(==)"],
                      [[:var, left_vars[i]], [:var, right_vars[i]]]
                    ]

                  else
                    lookup.call(Type.constraint(INTERFACE, arg_type, origin)) => Ok[impl]

                    [:call,
                      [:impl_value, impl, "(==)"],
                      [[:var, left_vars[i]], [:var, right_vars[i]]]
                    ]
                  end
                end

              body =
                if comparisons.empty?
                  [true]
                else
                  first_comparison, *rest = comparisons
                  [rest.reduce(first_comparison) { |acc, item| [:and, acc, item] }]
                end

              [[:list, [left_pattern, right_pattern]], body]
            end

            def derive_record_eq(constraint, fields, lookup)
              field_types = fields.values
              field_keys  = fields.keys

              resolve_field_deps(field_types, lookup, constraint.origin)
                .and_then do |deps|
                  field_keys
                    .each_with_index.map { |field_name, idx|
                      left  = [:access, [:var, 'one'],   field_name]
                      right = [:access, [:var, 'other'], field_name]
                      [:call, [:impl_arg, idx, '(==)'], [left, right]]
                    }
                    .then { build_record_impl(constraint, it, deps) }
                    .then { Ok[it] }
              end
            end

            def derive_struct_eq(constraint, struct_sym, type_args, registry, lookup, entry_name)
              fields      = struct_fields(struct_sym, type_args, registry)
              field_types = fields.map { |_, t| t }
              field_names = fields.map { |k, _| k.to_s }

              resolve_field_deps(field_types, lookup, constraint.origin).and_then do |deps|
                comparisons = field_names.each_with_index.map { |field_name, idx|
                  left  = [:access, [:var, 'one'],   field_name]
                  right = [:access, [:var, 'other'], field_name]
                  [:call, [:impl_arg, idx, '(==)'], [left, right]]
                }
                Ok[build_record_impl(constraint, comparisons, deps)]
              end
            end

            def resolve_field_deps(field_types, lookup, origin)
              field_types
                .map { lookup.call(Type.constraint(INTERFACE, it, origin)) }
                .then { Results.sequence(it) }
            end

            def build_record_impl(constraint, comparisons, deps)
              body = comparisons.empty? ? true : comparisons.reduce { |a, b| [:and, a, b] }
              eq_fn = Symbol::DerivedFunction.new(params: ['one', 'other'], body:)

              Symbol::Implementation.new(
                module_name: nil,
                interface: Symbol.type_ref_from_qualified_name(constraint.interface),
                type: constraint.type,
                type_params: [],
                constraints: [],
                functions: { '(==)' => eq_fn },
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

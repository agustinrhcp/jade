module Jade
  module Frontend
    module TypeChecking
      module Constraints
        module Deriving
          module Eq
            extend self

            INTERFACE = 'Basics.Eq'

            def supports?(interface) = interface == INTERFACE

            def derive(constraint, registry, entry_name, &lookup)
              resolve(constraint, registry, entry_name, lookup)
            end

            private

            def resolve(constraint, registry, entry_name, lookup)
              case [constraint.interface, constraint.type]
              in [INTERFACE, Type::Application(constructor:, args:)]
                impl = registry
                  .implementations[[constraint.interface, constructor.name]] ||
                    derive_union_eq(constraint, constructor, registry, lookup)

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
                    interface: constraint.interface,
                    type: constraint.type,
                    type_params: args,
                    constraints: deps,
                    functions: impl.functions,
                    deps: resolved_deps,
                    decl_span: nil,
                  )

                else
                  impl
                end
                  .then { Ok[it] }

              in [INTERFACE, Type::AnonymousRecord(fields:)]
                derive_record_eq(constraint, fields, lookup)
                  .then { Ok[it] }

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

            def derive_union_eq(constraint, constructor, registry, lookup)
              symbol =
                Symbol
                  .type_ref_from_qualified_name(constructor.name)
                  .then { registry.lookup(it) }
                  .then { |sym| sym.with(variants: sym.variants.map { registry.lookup(it) }) }

              type_vars = symbol.type_params.map(&:name)
              constraints = type_vars.map { Type.constraint(INTERFACE, Type.var(it), nil) }
              index_map = type_vars.each_with_index.map.to_h

              cases =
                symbol.variants.map do |variant|
                  build_variant_case(variant, index_map, lookup)
                end + [[[:_], [false]]]

              subject = [:list, [[:var, "one"], [:var, "other"]]]

              eq_fn = Symbol::DerivedFunction
                .new(
                  params: ["one", "other"],
                  body: [:case, subject, cases]
                )

              neq_fn = Symbol::DerivedFunction
                .new(
                  params: ["one", "other"],
                  body: [:!, [:case, subject, cases]]
                )

              if type_vars.empty? && constraints.empty?
                Symbol::Implementation.new(
                   module_name: nil,
                   interface: constraint.interface,
                   type: constraint.type,
                   type_params: [],
                   constraints: [],
                   functions: { '(==)' => eq_fn, '(!=)' => neq_fn },
                   deps: [],
                   decl_span: nil,
                )

              else
                Symbol::ImplementationTemplate.new(
                  interface: constraint.interface,
                  type: constraint.type,
                  type_params: type_vars.map { Type.var(it) },
                  constraints:,
                  functions: { '(==)' => eq_fn, '(!=)' => neq_fn },
                )
              end
            end

            def build_variant_case(variant, index_map, lookup)
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
                    lookup.call(Type.constraint(INTERFACE, arg_type, nil)) => Ok[impl]

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
              deps = fields.values.map { |field_type|
                lookup.call(Type.constraint(INTERFACE, field_type, nil)) => Ok[impl]; impl
              }

              comparisons = fields.keys.each_with_index.map { |field_name, idx|
                left  = [:access, [:var, 'one'],   field_name]
                right = [:access, [:var, 'other'], field_name]
                [:call, [:impl_arg, idx, '(==)'], [left, right]]
              }

              body = comparisons.empty? ? true : comparisons.reduce { |a, b| [:and, a, b] }
              eq_fn  = Symbol::DerivedFunction.new(params: ['one', 'other'], body:)
              neq_fn = Symbol::DerivedFunction.new(params: ['one', 'other'], body: [:!, body])

              Symbol::Implementation.new(
                module_name: nil,
                interface: constraint.interface,
                type: constraint.type,
                type_params: [],
                constraints: [],
                functions: { '(==)' => eq_fn, '(!=)' => neq_fn },
                deps:,
                decl_span: nil,
              )
            end
          end
        end
      end
    end
  end
end

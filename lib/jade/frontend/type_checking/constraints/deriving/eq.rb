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
              resolve_constraint(constraint, registry, entry_name, lookup)
            end

            private

            def derive_union(constraint, symbol, registry, lookup, entry_name)
              type_vars = symbol.type_params.map(&:name)
              index_map = type_vars.each_with_index.map.to_h
              variants  = symbol.variants.map { registry.lookup(it) }

              return native_eq(constraint, type_vars) if variants.empty?

              concrete = variants
                .flat_map(&:args)
                .reject { it in Symbol::Variable }
                .map { instantiate(it, {}, registry) }
                .uniq


              concrete
                .map { lookup.call(Type.constraint(INTERFACE, it, constraint.origin)) }
                .then { Results.sequence(it) }
                .and_then do |deps|
                  cases = variants.map {
                    build_variant_case(it, index_map, concrete, registry, constraint.origin)
                  }

                  eq_fn = Symbol::DerivedFunction.new(
                    params: ["one", "other"],
                    body: [:case,
                      [:list, [[:var, "one"], [:var, "other"]]],
                      cases + [[[:_], [false]]],
                    ],
                  )

                  Ok[build_union_impl(constraint, type_vars, concrete, eq_fn, deps)]
                end
            end

            # A variant-less union stands in for an opaque native — `Decode.Value`,
            # `List` — so there is nothing to match on and equality is Ruby's.
            def native_eq(constraint, type_vars)
              Symbol::DerivedFunction
                .new(params: ["one", "other"], body: [:==, [:var, "one"], [:var, "other"]])
                .then { Ok[build_union_impl(constraint, type_vars, [], it, [])] }
            end

            def build_union_impl(constraint, type_vars, concrete, eq_fn, deps)
              return implementation(constraint, { '(==)' => eq_fn }, deps:) if type_vars.empty?

              Symbol::ImplementationTemplate.new(
                interface: Symbol.type_ref_from_qualified_name(constraint.interface),
                type: constraint.type,
                type_params: type_vars.map { Type.var(it) },
                constraints: union_constraints(constraint, type_vars, concrete),
                functions: { '(==)' => eq_fn },
              )
            end

            def build_variant_case(variant, index_map, concrete, registry, origin)
              field_count = variant.args.length

              left_vars  = (0...field_count).map { |i| "l#{i}" }
              right_vars = (0...field_count).map { |i| "r#{i}" }

              left_pattern  = [:constructor, variant.qualified_name, left_vars]
              right_pattern = [:constructor, variant.qualified_name, right_vars]

              comparisons =
                variant.args.each_with_index.map do |arg_type, i|
                  idx =
                    case arg_type
                    in Symbol::Variable(name:) then index_map[name]
                    else
                    index_map.size + concrete.index(instantiate(arg_type, {}, registry))
                    end

                  [:call,
                    [:impl_arg, idx, "(==)"],
                    [[:var, left_vars[i]], [:var, right_vars[i]]]
                  ]
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

            def derive_record(constraint, fields, lookup)
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

            def derive_struct(constraint, struct_sym, type_args, registry, lookup, entry_name)
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

            def build_record_impl(constraint, comparisons, deps)
              comparisons
                .then { it.empty? ? true : it.reduce { |a, b| [:and, a, b] } }
                .then { Symbol::DerivedFunction.new(params: ['one', 'other'], body: it) }
                .then { implementation(constraint, { '(==)' => it }, deps:) }
            end
          end
        end
      end
    end
  end
end

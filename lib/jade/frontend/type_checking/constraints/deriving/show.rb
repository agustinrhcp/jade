module Jade
  module Frontend
    module TypeChecking
      module Constraints
        module Deriving
          module Show
            extend self
            include Helpers

            INTERFACE = 'Show.Show'

            def supports?(interface) = interface == INTERFACE

            def derive(constraint, registry, entry_name, &lookup)
              resolve_constraint(constraint, registry, entry_name, lookup)
            end

            private

            def special_case(constraint)
              return nil unless constraint.type in Type::Function

              Ok[implementation(constraint, { 'show' => constant('<function>') })]
            end

            def constant(text)
              Symbol::DerivedFunction.new(params: ['value'], body: text)
            end

            def concat(parts)
              [:call, [:stdlib_fn, 'String.concat'], [[:list, parts]]]
            end

            def shown(dict_index, expr)
              [:call, [:impl_arg, dict_index, 'show'], [expr]]
            end

            def derive_union(constraint, symbol, registry, lookup, entry_name)
              type_vars = symbol.type_params.map(&:name)
              index_map = type_vars.each_with_index.map.to_h
              variants  = symbol.variants.map { registry.lookup(it) }

              concrete = variants
                .flat_map(&:args)
                .reject { it in Symbol::Variable }
                .map { instantiate(it, {}, registry) }
                .uniq

              return failed(constraint, entry_name) if variants.empty?

              concrete
                .map { lookup.call(Type.constraint(INTERFACE, it, constraint.origin)) }
                .then { Results.sequence(it) }
                .and_then do |deps|
                  cases = variants.map {
                    variant_case(it, index_map, concrete, registry)
                  }

                  show_fn = Symbol::DerivedFunction.new(
                    params: ['value'],
                    body: [:case, [:var, 'value'], cases],
                  )

                  Ok[union_impl(constraint, type_vars, concrete, show_fn, deps)]
                end
            end

            def union_impl(constraint, type_vars, concrete, show_fn, deps)
              return implementation(constraint, { 'show' => show_fn }, deps:) if type_vars.empty?

              Symbol::ImplementationTemplate.new(
                interface: Symbol.type_ref_from_qualified_name(constraint.interface),
                type: constraint.type,
                type_params: type_vars.map { Type.var(it) },
                constraints: union_constraints(constraint, type_vars, concrete),
                functions: { 'show' => show_fn },
              )
            end

            def variant_case(variant, index_map, concrete, registry)
              vars = (0...variant.args.length).map { |i| "a#{i}" }
              name = variant.qualified_name.split('.').last
              pattern = [:constructor, variant.qualified_name, vars]

              return [pattern, [name]] if vars.empty?

              rendered = variant.args.each_with_index.map do |arg_type, i|
                idx =
                  case arg_type
                  in Symbol::Variable(name: var_name) then index_map[var_name]
                  else
                    index_map.size + concrete.index(instantiate(arg_type, {}, registry))
                  end

                shown(idx, [:var, vars[i]])
              end

              parts = [name, '('] + intersperse(rendered, ', ') + [')']

              [pattern, [concat(parts)]]
            end

            def intersperse(items, separator)
              items.flat_map { [separator, it] }.drop(1)
            end

            def derive_struct(constraint, struct_sym, type_args, registry, lookup, entry_name)
              fields = struct_fields(struct_sym, type_args, registry)
              name = struct_sym.qualified_name.split('.').last

              resolve_field_deps(fields.map { |_, type| type }, lookup, constraint.origin)
                .and_then do |deps|
                  rendered = fields.each_with_index.map { |(field, _), idx|
                    [:call, [:stdlib_fn, 'String.concat'], [[:list, [
                      "#{field}: ",
                      shown(idx, [:access, [:var, 'value'], field.to_s]),
                    ]]]]
                  }

                  parts = [name, ' { '] + intersperse(rendered, ', ') + [' }']

                  Ok[record_impl(constraint, concat(parts), deps)]
                end
            end

            def derive_record(constraint, fields, lookup)
              resolve_field_deps(fields.values, lookup, constraint.origin)
                .and_then do |deps|
                  rendered = fields.keys.each_with_index.map { |field, idx|
                    [:call, [:stdlib_fn, 'String.concat'], [[:list, [
                      "#{field}: ",
                      shown(idx, [:access, [:var, 'value'], field.to_s]),
                    ]]]]
                  }

                  parts = ['{ '] + intersperse(rendered, ', ') + [' }']

                  Ok[record_impl(constraint, concat(parts), deps)]
                end
            end

            def record_impl(constraint, body, deps)
              Symbol::DerivedFunction
                .new(params: ['value'], body:)
                .then { implementation(constraint, { 'show' => it }, deps:) }
            end
          end
        end
      end
    end
  end
end

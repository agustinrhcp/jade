module Jade
  module Frontend
    module TypeChecking
      module Constraints
        module Deriving
          # jade-sql's interface, derived here rather than there: the
          # deriving framework is not extensible, and this stays inert
          # without jade-sql, since nothing else names the interface.
          module SqlMapper
            extend self
            include Helpers

            INTERFACE = 'Sql.SqlMapper'
            ASSIGNMENT = 'Sql.Assignment'
            ASSIGNMENT_FIELDS = %w[col value_sql params].freeze

            def supports?(interface) = interface == INTERFACE

            def derive(constraint, registry, entry_name, &lookup)
              return failed(constraint, entry_name) unless assignment_matches?(registry)

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

            # The interface is matched by name, so some other module called
            # `Sql` would otherwise be derived against as though it were
            # jade-sql — building its Assignment with the wrong arity, and
            # failing at runtime rather than here.
            def assignment_matches?(registry)
              Symbol
                .type_ref_from_qualified_name(ASSIGNMENT)
                .then { registry.lookup(it) }
                .then do
                  it in Symbol::Struct(record_type: { fields: }) and
                    fields.keys.map(&:to_s) == ASSIGNMENT_FIELDS
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

            # One column per variant, so each variant carries exactly the
            # value that column is set to.
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
                .map { implementation(constraint, union_body(vs), it) }
            end

            def encodable_dep(variant, registry)
              variant
                .args
                .first
                .then { instantiate(it, {}, registry) }
                .then { Type.constraint('Encode.Encodable', it, nil) }
            end

            def union_body(variants)
              variants
                .each_with_index
                .map { |v, idx| [[:constructor, v.qualified_name, ['x']], [assignment(v, idx)]] }
                .then { [:case, [:var, 'f'], it] }
            end

            def assignment(variant, idx)
              [:call,
                [:struct_constructor, ASSIGNMENT, 3],
                [
                  wire_name(variant),
                  '?',
                  [:list, [[:call, [:impl_arg, idx, 'encoder'], [[:var, 'x']]]]],
                ],
              ]
                .then { [:list, [it]] }
            end

            def failed(constraint, entry_name)
              Err[
                Error::DerivationFailed.new(
                  entry_name, constraint.origin&.range, constraint:, trace: [],
                )
              ]
            end

            def implementation(constraint, body, deps)
              Symbol::Implementation.new(
                module_name: nil,
                interface: Symbol.type_ref_from_qualified_name(constraint.interface),
                type: constraint.type,
                type_params: [],
                constraints: [],
                functions: { 'to_assigns' => Symbol::DerivedFunction.new(params: ['f'], body:) },
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

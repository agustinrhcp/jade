module Jade
  module Frontend
    module TypeChecking
      module Constraints
        module Deriving
          # jade-sql's interface, derived here rather than there: the
          # deriving framework is not extensible, and this stays inert
          # without jade-sql, since nothing else names the interface.
          module Assignable
            extend self
            include Helpers

            INTERFACE = 'Sql.Assignable'
            ASSIGNMENT = 'Sql.Assignment'
            ASSIGNMENT_FIELDS = %w[col value_sql params].freeze
            WRITES = 'Sql.Writes'
            EXPR = 'Sql.Expr'

            def supports?(interface) = interface == INTERFACE

            def derive(constraint, registry, entry_name, &lookup)
              return failed(constraint, entry_name) unless assignment_matches?(registry)

              case constraint.type
              in Type::Application(constructor: Type::Constructor(name: WRITES), args: [cols, value])
                derive_writes(constraint, cols, value, registry, lookup, entry_name)

              in Type::Application(constructor: Type::Constructor(name:), args:)
                Symbol
                  .type_ref_from_qualified_name(name)
                  .then { registry.lookup(it) }
                  .then { derive_for(constraint, it, args, registry, lookup, entry_name) }

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

            def derive_for(constraint, symbol, args, registry, lookup, entry_name)
              case symbol
              in Symbol::Union if args.empty? && single_payload?(symbol, registry)
                derive_union(constraint, symbol, registry, lookup, entry_name)

              in Symbol::Struct
                derive_struct(constraint, symbol, args, registry, lookup, entry_name)

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

            # `Writes(c, a)` pairs a value with the columns of the table it is
            # headed for, so each field can be checked against a real column
            # instead of becoming one by having a name.
            def derive_writes(constraint, cols, value, registry, lookup, entry_name)
              # Which columns and which fields is not knowable until the caller
              # says; deriving here would report "cannot derive" for a table
              # nobody has named yet.
              if (cols.unbound_vars + value.unbound_vars).any?
                Error::UnresolvedConstraint
                  .new(entry_name, constraint.origin&.range, constraint:)
                  .then { return Err[it] }
              end

              columns = fields_of(cols, registry)
              fields = fields_of(value, registry)

              return failed(constraint, entry_name) if columns.nil? || fields.nil?

              fields
                .map { |name, type| check_column(columns, name, type) }
                .compact
                .first
                .then { return failed(constraint, entry_name, reason: it) if it }

              fields
                .map { |_, type| Type.constraint('Encode.Encodable', type, nil) }
                .map { lookup.call(it) }
                .then { Results.sequence(it) }
                .map { implementation(constraint, writes_body(fields), it) }
            end

            def check_column(columns, name, type)
              column = column_name(name)

              case columns[column]
              in nil
                "no column `#{column}`"

              in ^type
                nil

              in found
                "column `#{column}` is #{found}, field is #{type}"
              end
            end

            # Columns are `Expr(t)`; the value's field carries the `t`.
            def fields_of(type, registry)
              case type
              in Type::Application(constructor: Type::Constructor(name:), args:)
                Symbol
                  .type_ref_from_qualified_name(name)
                  .then { registry.lookup(it) }
                  .then do
                    case it
                    in Symbol::Struct => sym
                      struct_fields(sym, args, registry)
                        .to_h { |field, t| [column_name(field), unwrap_expr(t)] }

                    else nil
                    end
                  end

              else nil
              end
            end

            def unwrap_expr(type)
              case type
              in Type::Application(constructor: Type::Constructor(name: EXPR), args: [inner])
                inner

              else type
              end
            end

            def writes_body(fields)
              fields
                .each_with_index
                .map { |(name, _), idx| writes_assignment(name, idx) }
                .then { [:list, it] }
            end

            def writes_assignment(name, idx)
              [:call,
                [:struct_constructor, ASSIGNMENT, 3],
                [
                  column_name(name),
                  '?',
                  [:list,
                    [[:call,
                      [:impl_arg, idx, 'encoder'],
                      [[:access, [:access, [:var, 'f'], 'value'], name.to_s]],
                    ]],
                  ],
                ],
              ]
            end

            def derive_struct(constraint, struct_sym, args, registry, lookup, entry_name)
              fields = struct_fields(struct_sym, args, registry)

              fields
                .map { |_, type| Type.constraint('Encode.Encodable', type, nil) }
                .map { lookup.call(it) }
                .then { Results.sequence(it) }
                .map { implementation(constraint, struct_body(fields), it) }
            end

            def struct_body(fields)
              fields
                .each_with_index
                .map { |(name, _), idx| field_assignment(name, idx) }
                .then { [:list, it] }
            end

            def field_assignment(name, idx)
              [:call,
                [:struct_constructor, ASSIGNMENT, 3],
                [
                  column_name(name),
                  '?',
                  [:list,
                    [[:call, [:impl_arg, idx, 'encoder'], [[:access, [:var, 'f'], name.to_s]]]],
                  ],
                ],
              ]
            end

            def column_name(field)
              field
                .to_s
                .then { it.end_with?('_') ? it.delete_suffix('_') : it }
                .then { Lexer::KEYWORDS.include?(it) ? it : field.to_s }
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

            def failed(constraint, entry_name, reason: nil)
              Err[
                Error::DerivationFailed.new(
                  entry_name, constraint.origin&.range, constraint:, trace: [], reason:,
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

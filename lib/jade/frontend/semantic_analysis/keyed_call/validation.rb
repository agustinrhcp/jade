module Jade
  module Frontend
    module SemanticAnalysis
      module KeyedCall
        module Validation
          extend self

          def errors(node, fields, parent, constructor, registry, entry)
            duplicate_field_errors(fields, entry) +
              kwargs_callee_errors(node, parent, entry) +
              field_set_errors(node, fields, parent, constructor, registry, entry)
          end

          def expected_field_keys(parent, constructor, registry)
            case parent
            in Symbol::Struct then struct_record_keys(parent, registry)
            in Symbol::Union  then variant_record_keys(constructor)
            else []
            end
          end

          private

          def duplicate_field_errors(fields, entry)
            fields
              .group_by(&:key)
              .filter_map do |key, group|
                next if group.size < 2

                Error::DuplicateField.new(
                  entry.name,
                  group.last.range,
                  field: key,
                )
              end
          end

          def kwargs_callee_errors(node, parent, entry)
            case parent
            in Symbol::Struct | Symbol::Union
              []
            else
              [Error::KwargsOnNonConstructor.new(entry.name, node.range)]
            end
          end

          def field_set_errors(node, fields, parent, constructor, registry, entry)
            parent in Symbol::Struct | Symbol::Union or return []

            expected = expected_field_keys(parent, constructor, registry)
            provided = fields.map(&:key)
            type_name = constructor_type_name(parent, constructor)

            unknown = (provided - expected).map do |key|
              Error::UnknownField.new(
                entry.name,
                fields.find { it.key == key }.range,
                type_name:,
                field: key,
                expected:,
              )
            end

            (expected - provided)
              .then do |missing|
                if missing.empty?
                  []
                else
                  Error::MissingField
                    .new(
                      entry.name,
                      node.range,
                      type_name:,
                      fields: missing,
                    )
                    .then { [it] }
                end
              end
              .then { unknown + it }
          end

          def struct_record_keys(struct_sym, registry)
            case struct_sym.record_type
            in Symbol::RecordType(fields:)
              fields.keys

            in Symbol::TypeRef => ref
              struct_record_keys(registry.lookup(ref), registry)
            end
          end

          def variant_record_keys(constructor)
            case constructor.args
            in [Symbol::RecordType(fields:)] then fields.keys
            else []
            end
          end

          def constructor_type_name(parent, constructor)
            case parent
            in Symbol::Struct then parent.name
            in Symbol::Union  then constructor.name
            end
          end
        end
      end
    end
  end
end

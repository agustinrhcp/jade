module TypeChecker
  module Record
    extend self

    def check_instantiation(node, context)
      node => AST::RecordInstantiation(name:, fields:)

      type = context.resolve_type(name)

      unless type
        # This should be caught by semantic analysis
        return Err[[
          Error.new("Undefined record type '#{name}'", range: node.range)
        ]]
      end

      fields
        .reduce(Ok[[[], context]]) do |acc, field|
          acc
            .and_then do |(checked_acc, previous_context)|
              check_field_assignment(field, previous_context, type)
                .map do |(checked_field, next_context)|
                  [checked_acc.concat([checked_field]), next_context]
                end
                .map_error { [it, previous_context]}
            end
            .on_err do |(errors_acc, previous_context)|
              check_field_assignment(field, previous_context, type)
                .map_error { [errors_acc.concat(it), previous_context] }
                .and_then { acc }
            end
        end
        .map_error(&:first)
        .map do |(checked_fields, new_context)|
          [
            node.with(fields: checked_fields)
              .annotate(Substitution.substitute(type, new_context)),
            new_context,
          ]
        end
    end

    private

    def check_field_assignment(node, context, record_type)
      node => AST::RecordFieldAssign(name:, expression:)

      TypeChecker
        .check(expression, context)
        .and_then do |(checked_field, next_context)|
          case record_type.fields[name]
          in Type::Generic(name:)
            generic_type = next_context.resolve_substitution(name)

            if generic_type.nil?
              Ok[[checked_field, next_context.extend_substitution(name, checked_field.type)]]
            else
              return Ok[[checked_field, next_context]] if checked_field.type == generic_type

              Err[[Error.new("Generic '#{name}' was previously bound to #{generic_type}, but is now expected to be #{checked_field.type}", range: field.range)]]
            end
          else
            if checked_field.type == record_type.fields[name]
              Ok[[checked_field, next_context]] 
            else
              Err[[Error.new("Field '#{name}' expects #{record_type.fields[name]}, got #{checked_field.type}", range: node.range)]]
            end
          end
        end
    end
  end
end

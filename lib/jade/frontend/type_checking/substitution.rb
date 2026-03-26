module Jade
  module Frontend
    module TypeChecking
      Substitution = Data.define(:mappings) do
        def initialize(mappings: {})
          super
        end

        def empty?
          mappings.empty?
        end

        def apply(type)
          case type
          in Type::Constraint(type: constraint_type)
            type.with(type: apply(constraint_type))

          in Type::Function(args:, return_type:)
            type
              .with(args: args.map { apply(it) })
              .with(return_type: apply(return_type) )

          in Type::Constructor
            type

          in Type::Var(id:)
            mapping = mappings[id]

            return type unless mapping

            case mapping
            in Type::Var(id: ^id)
              type.rigid? ? type : mapping

            in Type::Var
              type.rigid? ? apply(mapping.make_rigid) : apply(mapping)

            else
              type.rigid? ? type : mapping
            end

          in Type::Application(args:)
            type
              .with(args: args.map { apply(it) })

          in Type::AnonymousRecord(fields:, row_var:)
            applied_fields = fields.transform_values { apply(it) }
  
            if row_var.nil?
              type.with(fields: applied_fields)
            else
              resolved = apply(row_var)
              case resolved
              in Type::AnonymousRecord(fields: extra_fields, row_var: new_row_var)
                Type.anonymous_record(applied_fields.merge(extra_fields), new_row_var)
              else
                type.with(fields: applied_fields, row_var: resolved)
              end
            end
          end
        end

        def bind(name, type)
          with(mappings: mappings.merge(name => type))
        end

        def compose(other)
          other_applied_to_self = mappings
            .transform_values { |t| other.apply(t) }
            .then { Substitution[it] }

          self_applied_to_other = other.mappings
            .transform_values { |t| other_applied_to_self.apply(t) }

          composed = other_applied_to_self.mappings
            .merge(self_applied_to_other)
            .then { Substitution[it] }

          # stabilize
          composed
            .mappings
            .transform_values { |t| composed.apply(t) }
            .then { Substitution[it] }
        end
      end
    end
  end
end

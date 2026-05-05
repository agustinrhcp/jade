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

        def self.empty
          EMPTY
        end

        def apply(type)
          case type
          in Type::Constraint(type: constraint_type)
            type.with(type: apply(constraint_type))

          in Type::Function(args:, return_type:)
            type.with(
              args: args.map { apply(it) },
              return_type: apply(return_type),
            )

          in Type::Constructor
            type

          in Type::Var(id:)
            mapping = mappings[id]

            return type unless mapping

            case mapping
            in Type::Var(id: ^id)
              mapping

            else
              apply(mapping)
            end

          in Type::PartialApplication(constructor:, args:)
            type.with(constructor: apply(constructor), args: args.map { apply(it) })

          in Type::Application(args:)
            case apply(type.constructor)
            in Type::PartialApplication(constructor:, args: tail_args)
              Type::Application[constructor, args.map { apply(it) } + tail_args]

            in constructor
              type.with(constructor:, args: args.map { apply(it) })
            end

          in Type::AnonymousRecord(fields:, row_var:)
            applied_fields = fields.transform_values { apply(it) }

            return type.with(fields: applied_fields) if type.closed?

            case apply(row_var)
            in Type::AnonymousRecord(fields: extra_fields, row_var: new_row_var)
              Type.anonymous_record(applied_fields.merge(extra_fields), new_row_var)

            in Type::Var => applied_row_var
              type.with(fields: applied_fields, row_var: applied_row_var)

            in Type::Application => struct
              type.with(fields: applied_fields, row_var: struct)

            end
          end
        end

        def bind(name, type)
          with(mappings: mappings.merge(name => type))
        end

        def compose(other)
          return self if other.mappings.empty?
          return other if mappings.empty?

          Substitution[mappings.merge(other.mappings)]
        end
      end

      Substitution::EMPTY = Substitution[{}].freeze
    end
  end
end

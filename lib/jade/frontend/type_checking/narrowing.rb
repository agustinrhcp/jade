module Jade
  module Frontend
    module TypeChecking
      # Unification is symmetric, so a body that pins a variable its
      # declaration quantifies simply binds it, and a call site instantiating
      # the declaration afresh never sees that it did.
      module Narrowing
        extend self

        # Against a fresh copy of the declaration, since a narrowing collected
        # in an earlier round is already part of the generalised type and the
        # substitution no longer shows it.
        def against_declaration(declared, actual)
          pairs(declared, actual).then do |found|
            found.find { |(_, type)| !type.is_a?(Type::Var) } || merged(found)
          end
        end

        private

        def merged(found)
          found
            .uniq { |(var, _)| var.id }
            .group_by { |(_, type)| type.id }
            .values
            .find { it.size > 1 }
            &.then { |((var, _), (other, _))| [var, other] }
        end

        def pairs(declared, actual)
          case declared
          in Type::Var
            [[declared, actual]]

          in Type::Application(constructor:, args:)
            pairs(constructor, actual.constructor) + zipped(args, actual.args)

          in Type::Function(args:, return_type:)
            zipped(args, actual.args) + pairs(return_type, actual.return_type)

          in Type::AnonymousRecord(fields:, row_var:)
            fields.flat_map { |name, type| pairs(type, actual.fields.fetch(name)) } +
              row_pairs(row_var, fields, actual)

          else
            []
          end
        end

        def zipped(declared, actual)
          declared
            .zip(actual)
            .flat_map { |(d, a)| pairs(d, a) }
        end

        def row_pairs(row_var, fields, actual)
          return [] unless row_var

          (actual.fields.keys - fields.keys).empty? && actual.row_var ?
            pairs(row_var, actual.row_var) :
            [[row_var, actual]]
        end
      end
    end
  end
end

module Jade
  module Frontend
    module TypeChecking
      # Unification is symmetric, so pinning a variable a declaration
      # quantifies simply binds it, and a call site instantiating that
      # declaration afresh never sees that it did. Two places can do it: a
      # function's own body, and an implementation against the method it
      # implements.
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


        # An implementation is the other place a quantified variable can be
        # pinned: the method promises a variable each call site settles, and
        # unification will happily bind it to the implementation's own.
        #
        # The interface's own parameter is exempt — binding that to the
        # implemented type is what an implementation is.
        def against_method(sig_type, t_var, head_vars, substitution)
          sig_type
            .unbound_vars
            .reject { it.id == t_var.id }
            .filter_map { pinned(it, substitution.apply(it), head_vars) }
            .uniq(&:first)
        end

        private

        # Pinned to one of the implemented type's own variables is the common
        # case, and naming it reads as nonsense when the two are spelled alike.
        def pinned(var, applied, head_vars)
          case applied
          in Type::Var(id:) if !head_vars.include?(id) then nil
          in Type::Var then [var.name, 'the type this implements']
          else [var.name, "`#{applied}`"]
          end
        end

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

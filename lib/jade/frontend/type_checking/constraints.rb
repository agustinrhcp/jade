module Jade
  module Frontend
    module TypeChecking
      module Constraints
        extend self

        def solve(constraint, registry, entry_name)
          case constraint.type
          in Type::Var
            Error::UnresolvedConstraint.new(
              entry_name,
              constraint.origin.range,
              constraint:,
            )
              .then { [it] }
          else
            case lookup(constraint, registry)

            in nil
              Error::MissingImplementation.new(
                entry_name,
                constraint.origin.range,
                constraint:
              )
              .then { [it] }

            in _ => impl
              constraint.origin.dictionaries.concat([constraint])
              []
            end
          end
        end

        def lookup(constraint, registry)
          case constraint.type
          in Type::Application(constructor:)
            constructor.name

          else
            constraint.type.to_s
          end
            .then { [constraint.interface, it] }
            .then { registry.implementations[it] }
        end
      end
    end
  end
end

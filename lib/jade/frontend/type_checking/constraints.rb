module Jade
  module Frontend
    module TypeChecking
      module Constraints
        extend self

        def lookup(constraint, registry, entry_name)
          case constraint.type
          in Type::Var
            Error::UnresolvedConstraint
              .new(entry_name, constraint.origin.range, constraint:)
              .then { Err[it] }

          else
            impl =
              case constraint.type
              in Type::Application(constructor:) then constructor.name
              else
                constraint.type.to_s
              end
              .then { registry.implementations[[constraint.interface, it]] }

            return Ok[impl] if impl

            Error::MissingImplementation
              .new(entry_name, constraint.origin.range, constraint:)
              .then { Err[it] }
          end
        end

        def attach_dictionary(constraint)
          constraint.origin.dictionaries.concat([constraint])
        end

        def solve_at_finalize(constraint, registry, entry_name)
          lookup(constraint, registry, entry_name)
            .map { |impl| attach_dictionary(constraint, impl); [] }
            .on_err(Error::UnresolvedConstraint) { Ok[[]] }
            .on_err { Ok[[it]] }
            .with_default([])
        end

        def solve_at_call_site(constraint, registry, entry_name)
          lookup(constraint, registry, entry_name)
            .map { attach_dictionary(constraint); [] }
            .on_err(Error::UnresolvedConstraint) { Ok[[]] }
            .on_err(Error::MissingImplementation) { |e| Ok[[e]] }
            .with_default([])
        end
      end
    end
  end
end

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

            return derive(constraint, registry, entry_name) if derivable?(constraint)

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
            .map { |impl| attach_dictionary(constraint); [] }
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

        def derive(constraint, registry, entry_name)
          case constraint.type
          in Type::AnonymousRecord(fields:)
            fields
              .values
              .map { lookup(constraint.with(type: it), registry, entry_name) }
              .then { sequence(it) }
          end
        end

        private

        def derivable?(constraint)
          case constraint.interface
          in 'Basics.Eq'
            true

          else
            false
          end
        end

        def sequence(list_of_results)
          list_of_results.reduce(Ok.new([])) do |acc, result|
            acc.map2(result) do |acc_list, item_result|
              acc_list + [item_result]
            end
          end
        end
      end
    end
  end
end

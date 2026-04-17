require 'jade/frontend/type_checking/constraints/deriving'

module Jade
  module Frontend
    module TypeChecking
      module Constraints
        extend self

        def resolve(constraint, registry, entry_name)
          if constraint.type in Type::Var
            Error::UnresolvedConstraint
              .new(entry_name, constraint.origin.range, constraint:)
              .then { return Err[it] }
          end

          if impl = lookup(constraint, registry)
            impl
              .extends
              .map do |iface_ref|
                Type
                  .constraint(
                    iface_ref.qualified_name,
                    constraint.type,
                    constraint.origin,
                  )
                .then { resolve(it, registry, entry_name) } => Ok[resolved]

                resolved
              end
              .then { impl.deps + it }
              .then { impl.with(deps: it) }
              .then { return Ok[it] }
          end

          if Deriving.derivable?(constraint.interface)
            Deriving
              .derive(constraint, registry, entry_name) { resolve(it, registry, entry_name) } 
              .then { return it }
          end

          Err[Error::MissingImplementation.new(entry_name, constraint.origin.range, constraint:)]
        end

        def attach_dictionary(constraint, impl)
          constraint.origin.dictionaries.concat([impl])
        end

        def solve_at_finalize(constraint, registry, entry_name)
          resolve(constraint, registry, entry_name)
            .map { |impl| attach_dictionary(constraint, impl); [] }
            .on_err(Error::UnresolvedConstraint) { Ok[[]] }
            .on_err { Ok[[it]] }
            .with_default([])
        end

        def solve_at_call_site(constraint, registry, entry_name)
          resolve(constraint, registry, entry_name)
            .map { |impl| attach_dictionary(constraint, impl); [] }
            .on_err(Error::UnresolvedConstraint) { Ok[[]] }
            .on_err(Error::MissingImplementation) { Ok[[it]] }
            .on_err(Error::DerivationFailed) { Ok[[it]] }
            .with_default([])
        end

        private

        def lookup(constraint, registry)
          key = case constraint.type
                in Type::Application(constructor:) then constructor.name
                in Type::Constructor(name:) then name
                else constraint.type.to_s
                end
          impl = registry.implementations[[constraint.interface, key]]
          impl if impl.is_a?(Symbol::Implementation)
        end
      end
    end
  end
end

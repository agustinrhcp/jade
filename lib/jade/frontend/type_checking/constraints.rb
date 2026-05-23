require 'jade/frontend/type_checking/constraints/deriving'

module Jade
  module Frontend
    module TypeChecking
      module Constraints
        extend self

        def resolve(constraint, registry, entry_name)
          if constraint.type in Type::Var
            Error::UnresolvedConstraint
              .new(entry_name, constraint.origin&.range, constraint:)
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

          constraint.origin.range
            .then { Error::MissingImplementation.new(entry_name, it, constraint:) }
            .then { Err[it] }
        end

        # An origin's dictionaries can be touched by multiple inference frames:
        # the call's own callee constraints attach here, and outer frames
        # also attach when args bubble up concretely. Var-typed markers' ids
        # may chain further as inference proceeds; the finalize-time
        # canonicalize pass walks the AST and rewrites them to their final
        # form so codegen can read marker.type.id directly.
        def attach_dictionary(constraint, impl)
          constraint => Type::Constraint(
            origin: { dictionaries: dicts },
            index:,
          )

          fail "constraint missing index: #{constraint}" if index == :unindex

          return if dicts[index].is_a?(Symbol::Implementation) &&
                    impl.is_a?(Type::Constraint)

          dicts[index] = impl
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
            .on_err(Error::MissingImplementation) { Ok[[it]] }
            .on_err(Error::DerivationFailed) { Ok[[it]] }
            .with_default([])
        end

        private

        def lookup(constraint, registry)
          key =
            case constraint.type
            in Type::Application(constructor:) then constructor.name
            in Type::PartialApplication(constructor:) then constructor.name
            in Type::Constructor(name:) then name
            else constraint.type.to_s
            end

          case registry.implementations[[constraint.interface, key]]
          in Symbol::Implementation => impl then impl
          else nil
          end
        end
      end
    end
  end
end

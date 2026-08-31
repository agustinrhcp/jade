require 'jade/frontend/type_checking/constraints/deriving'

module Jade
  module Frontend
    module TypeChecking
      module Constraints
        extend self

        # A derived instance is built by asking for its components' instances,
        # so a type that contains itself asks for the one being built. Nothing
        # ties that knot yet, so the walk is cut here rather than left to run
        # out of stack.
        def resolve(constraint, registry, entry_name, in_progress = ::Set[])
          key = [constraint.interface, constraint.type.to_s]

          if in_progress.include?(key)
            Error::RecursiveDerivation
              .new(entry_name, constraint.origin&.range, constraint:)
              .then { return Err[it] }
          end

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
                .then { resolve(it, registry, entry_name, in_progress) } => Ok[resolved]

                resolved
              end
              .then { impl.deps + it }
              .then { impl.with(deps: it) }
              .then { return Ok[it] }
          end

          if Deriving.derivable?(constraint.interface)
            Deriving
              .derive(constraint, registry, entry_name) do
                resolve(it, registry, entry_name, in_progress + [key])
              end
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
            in Type::Displayable => t then t.render
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

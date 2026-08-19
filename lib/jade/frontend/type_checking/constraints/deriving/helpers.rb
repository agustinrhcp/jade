module Jade
  module Frontend
    module TypeChecking
      module Constraints
        module Deriving
          module Helpers
            extend self

            # `union :Int` and friends are variant-less unions standing in
            # for native types, so an empty variant list is not an enum.
            def nullary?(union_sym, registry)
              variants(union_sym, registry)
                .then { it.any? && it.all? { it.args.empty? } }
            end

            def variants(union_sym, registry)
              union_sym.variants.map { registry.lookup(it) }
            end

            # The wire name a variant carries when nothing says otherwise.
            # Matches what hand-written mappings already use.
            def wire_name(variant)
              Source.snake_case(variant.name)
            end

            def struct_fields(struct_sym, type_args, registry)
              record = struct_sym.record_type
              type_param_names = struct_sym.type_params.map(&:name)
              subst = type_param_names.zip(type_args).to_h

              record
                .fields
                .map { |name, sym| [name, instantiate(sym, subst, registry)] }
            end

            def failed(constraint, entry_name)
              Err[
                Error::DerivationFailed
                  .new(entry_name, constraint.origin.range, constraint:, trace: [])
              ]
            end

            def implementation(constraint, functions, deps: [], type_params: [], constraints: [])
              Symbol::Implementation.new(
                module_name: nil,
                interface: Symbol.type_ref_from_qualified_name(constraint.interface),
                type: constraint.type,
                type_params:,
                constraints:,
                functions:,
                deps:,
                extends: [],
                decl_span: nil,
              )
            end

            # A free-var inner constraint falls back to the marker itself —
            # codegen resolves it from the caller's dict env.
            def resolve_dep(dep, lookup)
              lookup
                .call(dep)
                .on_err(Error::UnresolvedConstraint) {
                  dep.type.is_a?(Type::Var) ? Ok[dep] : Err[it]
                }
            end

            def resolve_field_deps(field_types, lookup, origin)
              field_types
                .map { lookup.call(Type.constraint(self::INTERFACE, it, origin)) }
                .then { Results.sequence(it) }
            end

            def resolve_constraint(constraint, registry, entry_name, lookup)
              special = special_case(constraint, lookup)
              return special if special

              case constraint.type
              in Type::Application(constructor:, args:)
                dispatch_type(constraint, constructor, args, registry, lookup, entry_name)
                  .on_err { return Err[it] } => Ok(impl)

                case impl
                in Symbol::ImplementationTemplate
                  instantiate_template(constraint, impl, args, lookup)
                else
                  Ok[impl]
                end

              in Type::AnonymousRecord(fields:)
                derive_record(constraint, fields, lookup)

              else
                failed(constraint, entry_name)
              end
            end

            def special_case(_constraint, _lookup)
              nil
            end

            def dispatch_type(constraint, constructor, args, registry, lookup, entry_name)
              existing = registry.implementations[[constraint.interface, constructor.name]]
              return Ok[existing] if existing

              Symbol
                .type_ref_from_qualified_name(constructor.name)
                .then { registry.lookup(it) }
                .then do |symbol|
                  case symbol
                  in Symbol::Union
                    derive_union(constraint, symbol, registry, lookup, entry_name)

                  in Symbol::Struct
                    derive_struct(constraint, symbol, args, registry, lookup, entry_name)

                  else
                    failed(constraint, entry_name)
                  end
                end
            end

            def instantiate_template(constraint, impl, args, lookup)
              deps = dependencies_of(impl, args)
              resolved = deps.filter_map { |dep|
                next if dep.type in Type::Var
                lookup.call(dep).on_err { return Err[it] } => Ok[found]
                found
              }

              Ok[
                implementation(
                  constraint, impl.functions,
                  deps: resolved, type_params: args, constraints: deps,
                )
              ]
            end

            def union_constraints(constraint, type_vars, concrete)
              type_vars
                .map { Type.var(it) }
                .concat(concrete)
                .map { Type.constraint(self::INTERFACE, it, constraint.origin) }
            end

            def dependencies_of(impl, args)
              subst = impl
                .type_params
                .map(&:id)
                .zip(args)
                .to_h

              impl
                .constraints
                .map { it.with(type: substitute_type(it.type, subst)) }
            end

            def substitute_type(type, subst)
              case type

              in Type::Var(id:)
                subst.fetch(id, type)

              in Type::Application(constructor:, args:)
                Type::Application.new(
                  constructor: constructor,
                  args: args.map { substitute_type(it, subst) }
                )

              in Type::AnonymousRecord(fields:)
                Type::AnonymousRecord.new(
                  fields: fields.transform_values { substitute_type(it, subst) }
                )

              else
                type
              end
            end

            def instantiate(sym, subst, registry)
              case sym
              in Symbol::Variable(name:)
                subst.fetch(name) { Type.var(nil, name) }

              in Symbol::TypeApplication(constructor:, args:)
                inner_args = args
                  .map { instantiate(it, subst, registry) }

                Symbol
                  .type_ref(constructor.module_name, constructor.name)
                  .then { registry.lookup(it) }
                  .then { type_application_to_type(it, inner_args) }

              in Symbol::TypeRef
                registry
                  .lookup(sym)
                  .then { type_application_to_type(it, []) }

              in Symbol::FunctionType(params:, return_type:)
                Type.function(
                  params.map { instantiate(it, subst, registry) },
                  instantiate(return_type, subst, registry),
                )
              end
            end

            def type_application_to_type(sym, args)
              case sym
              in Symbol::Union | Symbol::Struct
                Type
                  .constructor(sym.qualified_name)
                  .apply(args)
              end
            end
          end
        end
      end
    end
  end
end

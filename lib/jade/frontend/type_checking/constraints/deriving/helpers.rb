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

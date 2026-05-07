module Jade
  module Frontend
    module TypeChecking
      module Constraints
        module Deriving
          module Helpers
            extend self

            def struct_fields(struct_sym, type_args, registry)
              record = struct_sym.record_type
              type_param_names = struct_sym.type_params.map(&:name)
              subst = type_param_names.zip(type_args).to_h

              record
                .fields
                .map { |name, sym| [name, instantiate(sym, subst, registry)] }
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

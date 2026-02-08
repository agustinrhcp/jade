module Jade
  module Frontend
    module ForwardDeclaration
      module Helper
        def shallow_declare_node(ast, registry, entry)
          ForwardDeclaration.shallow_declare_node(ast, registry, entry)
        end

        def deep_declare_node(ast, entry, registry)
          ForwardDeclaration.deep_declare_node(ast, entry, registry)
        end

        def figure_out_type(entry, type)
          case type
          in AST::TypeVar(type:)
            Symbol.var(type)

          in AST::TypeName(type:)
            entry
              .lookup_type(type)
              .then { Symbol.type_application(it.to_ref, []) }

          in AST::TypeApplication(constructor:, args:)
            constructor_sym = entry.lookup_type(constructor.type)
            args
              .map { figure_out_type(entry, it) }
              .then { Symbol.type_application(constructor_sym.to_ref, it) }

          in AST::QualifiedTypeName(path:)
            *module_parts, type_name = path
            entry.lookup_qualified_type(module_parts.join('.'), type_name)

          in AST::TypeFunction(params:, return_type:)
            params
              .map { figure_out_type(entry, it) }
              .then { Symbol.function_type(it, figure_out_type(entry, return_type)) }

          in AST::TypeRecord(fields:, row_var:)
            row = row_var&.then { |row| Symbol.var(row.name) }

            fields
              .transform_values { figure_out_type(entry, it) }
              .then { Symbol.record_type(it, row) }

          end
        end
      end
    end
  end
end

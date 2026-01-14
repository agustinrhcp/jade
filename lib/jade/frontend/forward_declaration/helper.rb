module Jade
  module Frontend
    module ForwardDeclaration
      module Helper
          def shallow_declare_node(ast, registry, entry)
            ForwardDeclaration.shallow_declare_node(ast, registry, entry)
          end

          def deep_declare_node(ast, entry)
            ForwardDeclaration.deep_declare_node(ast, entry)
          end

        def figure_out_type(entry, type)
          case type
          in AST::TypeVar(type:)
            Symbol.var(type)

          in AST::TypeName(type:)
            entry.lookup_type(type)

          in AST::TypeApplication(constructor:)
            entry.lookup_type(constructor.type)

          in AST::QualifiedTypeName(path:)
            *module_parts, type_name = path
            entry.lookup_qualified_type(module_parts.join('.'), type_name)

          in AST::TypeFunction(params:, return_type:)
            params
              .map { figure_out_type(entry, it) }
              .then { Symbol.function_type(it, figure_out_type(entry, return_type)) }
          end
        end
      end
    end
  end
end

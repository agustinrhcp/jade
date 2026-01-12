module Jade
  module ModuleLoader
    module DependencyResolver
      extend self

      def resolve(entry, registry)
        case entry.ast
        in AST::Module(body:)
          resolve_body(body, entry, registry)

        in AST::Body
          resolve_body(entry.ast, entry, registry)
        end
      end

      private

      def resolve_body(body, entry, registry)
         body => AST::Body(expressions:)

        expressions
          .reduce([registry, []]) do |(acc_registry, acc_imports), ast_node|
            case ast_node
            in AST::ImportDeclaration(module_name:)
              # TODO: [ModuleLoaderRefactor] This is more of DependencyLoader
              [ModuleLoader.load_import(module_name, registry), acc_imports + [module_name]]

            else
              [acc_registry, acc_imports]
            end
          end
          .then { |registry, imports| registry.add_dependencies(entry, imports) }
      end
    end
  end
end

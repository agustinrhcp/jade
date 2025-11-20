module Jade
  module Frontend
    module ForwardDeclaration
      extend self

      def declare(ast, entry)
        shallow(ast, entry)
          .then { deep(ast, it) }
      end

      private

      def shallow(ast, entry)
        case ast
        in AST::FunctionDeclaration(name:)
          Symbol.predeclared_function(name)
            .then { entry.add_symbol(it) }

        in AST::Body(expressions:)
          expressions.reduce(entry) { |acc, expr| shallow(expr, acc) }

        else
          entry
        end
      end

      # TODO: [ForwardDeclaration:HandleErrors]
      def deep(ast, entry)
        case ast
        in AST::FunctionDeclaration(name:, params:, return_type:)
          params_types = params
            .map do |param|
              param => { type: AST::TypeReference(type:) }

              [param.name, entry.lookup_type(type)]
            end
            .to_h

          return_type => AST::TypeReference(type:)
          return_type_type = entry.lookup_type(type)

          Symbol
            .function(name, params_types, return_type_type)
            .then { entry.add_symbol(it) }

        in AST::Body(expressions:)
          expressions.reduce(entry) { |acc, expr| deep(expr, acc) }

        else
          entry
        end
      end
    end
  end
end

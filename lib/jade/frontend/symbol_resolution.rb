module Jade
  module Frontend
    module SymbolResolution
      extend self

      def resolve(node, registry, current_entry)
        case node
        in AST::Literal
          resolve_literal(node, registry, current_entry) 

        in AST::VariableBinding(expression:)
          node.with(expression: resolve(expression, registry, current_entry))

        in AST::Body(expressions:)
          expressions
            .map { resolve(it, registry, current_entry) }
            .then { node.with(expressions: it) }

        in AST::VariableReference
          node
        end
      end

      private

      def resolve_literal(node, _registry, _current_entry)
        node => AST::Literal(value:)

        symbol =
          case value
          in Integer
            Symbol::TypeRef['Basics.Int']

          in TrueClass | FalseClass
            Symbol::TypeRef['Basics.Bool']

          in String
            Symbol::TypeRef['String.String']
          end

        node.with(symbol:)
      end
    end
  end
end

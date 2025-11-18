module Jade
  module Frontend
    module SymbolResolution
      extend self

      def resolve(node, registry, current_entry)
        case node
        in AST::Literal
          resolve_literal(node, registry, current_entry) 

        in AST::VariableBinding(expression:)
          node
            .with(expression: resolve(expression, registry, current_entry))

        in AST::Body(expressions:)
          expressions
            .map { resolve(it, registry, current_entry) }
            .then { node.with(expressions: it) }

        in AST::VariableReference
          node

        in AST::FunctionDeclaration(name:, body:)
          symbol = current_entry
            .lookup_value(name)
            .to_ref

          resolve(body, registry, current_entry)
            .then { node.with(body: it, symbol:) }

        in AST::InfixApplication(left:, operator:, right:)
          symbol = current_entry
            .lookup_value("(#{operator.value})")
            .to_ref

          node
            .with(left: resolve(left, registry, current_entry))
            .with(right: resolve(right, registry, current_entry))
            .with(operator: operator.with(symbol:))
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

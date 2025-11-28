require 'jade/frontend/symbol_resolution/member_access'

module Jade
  module Frontend
    module SymbolResolution
      extend self

      def resolve_entry(entry, registry)
        resolve(entry.ast, registry, entry)
          .then { entry.with(ast: it) }
      end

      def resolve(node, registry, current_entry)
        case node
        in AST::Module(body:)
          node
            .with(body: resolve(body, registry, current_entry))

        in AST::ImportDeclaration
          node

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

        in AST::ConstructorReference(name:)
          current_entry
            .lookup_value(name)
            .to_ref
            .then { node.with(symbol: it) }

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

        in AST::FunctionCall(callee:, args:)
          node
            .with(callee: resolve(callee, registry, current_entry))
            .with(args: args.map { resolve(it, registry, current_entry) })

        in AST::TypeDeclaration(name:, variants:)
          symbol = current_entry
            .lookup_type(name)
            .to_ref

          node
            .with(symbol:, variants: variants.map { resolve(it, registry, current_entry) })

        in AST::VariantDeclaration(name:)
          current_entry
            .lookup_value(name)
            .to_ref
            .then { node.with(symbol: it) }

        in AST::MemberAccess(target:, name:)
          MemberAccess.resolve(node, registry, current_entry)
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

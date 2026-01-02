require 'jade/frontend/symbol_resolution/member_access'
require 'jade/frontend/symbol_resolution/literal'
require 'jade/frontend/symbol_resolution/variable_binding'
require 'jade/frontend/symbol_resolution/module'
require 'jade/frontend/symbol_resolution/import_declaration'

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
        in AST::Module
          Module.resolve(node, registry, current_entry)

        in AST::ImportDeclaration
          ImportDeclaration.resolve(node, registry, current_entry)

        in AST::Literal
          Literal.resolve(node, registry, current_entry) 

        in AST::VariableBinding
          VariableBinding.resolve(node, registry, current_entry)

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
            .with(
              symbol:,
              variants: variants.map { resolve(it, registry, current_entry) },
            )

        in AST::VariantDeclaration(name:)
          current_entry
            .lookup_value(name)
            .to_ref
            .then { node.with(symbol: it) }

        in AST::IfThenElse(condition:, if_branch:, else_branch:)
          node
            .with(condition: resolve(condition, registry, current_entry))
            .with(if_branch: resolve(if_branch, registry, current_entry))
            .with(else_branch: resolve(else_branch, registry, current_entry))

        in AST::CaseOf(expression:, branches:)
          branches
            .map { resolve(it, registry, current_entry) }
            .then { node.with(branches: it) }
            .with(expression: resolve(expression, registry, current_entry))

        in AST::CaseOfBranch(pattern:, body:)
          node
            .with(pattern: resolve(pattern, registry, current_entry)) 
            .with(body: resolve(body, registry, current_entry)) 

        in AST::Pattern::Literal(literal:)
          node.with(literal: resolve(literal, registry, current_entry))

        in AST::Pattern::Binding
          node

        in AST::Pattern::Wildcard
          node

        in AST::Pattern::Constructor(constructor:, patterns:)
          symbol = current_entry
            .lookup_value(constructor)
            .to_ref

          patterns
            .map { resolve(it, registry, current_entry) }
            .then { node.with(patterns: it, symbol:) }

        in AST::MemberAccess(target:, name:)
          MemberAccess.resolve(node, registry, current_entry)
        end
      end

      private

      def resolve_literal(node, _registry, _current_entry)
        node => AST::Literal(value:)

        symbol_from_literal_value(value)
          .then { node.with(symbol: it) }
      end

      def symbol_from_literal_value(value)
        case value
        in Integer
          Symbol::TypeRef['Basics.Int']

        in TrueClass | FalseClass
          Symbol::TypeRef['Basics.Bool']

        in String
          Symbol::TypeRef['String.String']
        end
      end
    end
  end
end

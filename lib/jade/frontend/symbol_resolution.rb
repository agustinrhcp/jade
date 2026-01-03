require 'jade/frontend/symbol_resolution/member_access'
require 'jade/frontend/symbol_resolution/literal'
require 'jade/frontend/symbol_resolution/variable_binding'
require 'jade/frontend/symbol_resolution/module'
require 'jade/frontend/symbol_resolution/import_declaration'
require 'jade/frontend/symbol_resolution/body'
require 'jade/frontend/symbol_resolution/variable_reference'
require 'jade/frontend/symbol_resolution/function_declaration'
require 'jade/frontend/symbol_resolution/constructor_reference'
require 'jade/frontend/symbol_resolution/infix_application'
require 'jade/frontend/symbol_resolution/function_call'
require 'jade/frontend/symbol_resolution/type_declaration'
require 'jade/frontend/symbol_resolution/variant_declaration'
require 'jade/frontend/symbol_resolution/if_then_else'
require 'jade/frontend/symbol_resolution/case_of'
require 'jade/frontend/symbol_resolution/case_of_branch'
require 'jade/frontend/symbol_resolution/pattern/literal'
require 'jade/frontend/symbol_resolution/pattern/binding'
require 'jade/frontend/symbol_resolution/pattern/wildcard'
require 'jade/frontend/symbol_resolution/pattern/constructor'

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

        in AST::Body
          Body.resolve(node, registry, current_entry)

        in AST::VariableReference
          VariableReference.resolve(node, registry, current_entry)

        in AST::ConstructorReference
          ConstructorReference.resolve(node, registry, current_entry)

        in AST::FunctionDeclaration
          FunctionDeclaration.resolve(node, registry, current_entry)

        in AST::InfixApplication
          InfixApplication.resolve(node, registry, current_entry)

        in AST::FunctionCall
          FunctionCall.resolve(node, registry, current_entry)

        in AST::TypeDeclaration
          TypeDeclaration.resolve(node, registry, current_entry)

        in AST::VariantDeclaration
          VariantDeclaration.resolve(node, registry, current_entry)

        in AST::IfThenElse
          IfThenElse.resolve(node, registry, current_entry)

        in AST::CaseOf
          CaseOf.resolve(node, registry, current_entry)

        in AST::CaseOfBranch
          CaseOfBranch.resolve(node, registry, current_entry)

        in AST::Pattern::Literal
          Pattern::Literal.resolve(node, registry, current_entry)

        in AST::Pattern::Binding
          Pattern::Binding.resolve(node, registry, current_entry)

        in AST::Pattern::Wildcard
          Pattern::Wildcard.resolve(node, registry, current_entry)

        in AST::Pattern::Constructor
          Pattern::Constructor.resolve(node, registry, current_entry)

        in AST::MemberAccess
          MemberAccess.resolve(node, registry, current_entry)
        end
      end
    end
  end
end

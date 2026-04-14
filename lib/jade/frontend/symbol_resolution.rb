require 'jade/frontend/symbol_resolution/helper'
require 'jade/frontend/symbol_resolution/error'

require 'jade/frontend/symbol_resolution/body'
require 'jade/frontend/symbol_resolution/case_of'
require 'jade/frontend/symbol_resolution/case_of_branch'
require 'jade/frontend/symbol_resolution/constructor_reference'
require 'jade/frontend/symbol_resolution/function_call'
require 'jade/frontend/symbol_resolution/function_declaration'
require 'jade/frontend/symbol_resolution/grouping'
require 'jade/frontend/symbol_resolution/if_then_else'
require 'jade/frontend/symbol_resolution/implementation'
require 'jade/frontend/symbol_resolution/implementation_function'
require 'jade/frontend/symbol_resolution/import_declaration'
require 'jade/frontend/symbol_resolution/interop_import_declaration'
require 'jade/frontend/symbol_resolution/lambda'
require 'jade/frontend/symbol_resolution/list'
require 'jade/frontend/symbol_resolution/literal'
require 'jade/frontend/symbol_resolution/member_access'
require 'jade/frontend/symbol_resolution/module'
require 'jade/frontend/symbol_resolution/pattern/binding'
require 'jade/frontend/symbol_resolution/pattern/constructor'
require 'jade/frontend/symbol_resolution/pattern/literal'
require 'jade/frontend/symbol_resolution/pattern/record'
require 'jade/frontend/symbol_resolution/pattern/wildcard'
require 'jade/frontend/symbol_resolution/record_field'
require 'jade/frontend/symbol_resolution/record_literal'
require 'jade/frontend/symbol_resolution/record_update'
require 'jade/frontend/symbol_resolution/struct_declaration'
require 'jade/frontend/symbol_resolution/type_declaration'
require 'jade/frontend/symbol_resolution/variable_binding'
require 'jade/frontend/symbol_resolution/variable_reference'
require 'jade/frontend/symbol_resolution/variant_declaration'

module Jade
  module Frontend
    module SymbolResolution
      extend self

      Result = Data.define(:node, :errors) do
        def map
          with(node: yield(node))
        end

        def self.sequence(results)
          Result[
            results.map(&:node),
            results.flat_map(&:errors),
          ]
        end

        def add_errors(errors_)
          with(errors: errors + errors_)
        end

        def to_result
          return Err[errors] if errors.any?

          Ok[node]
        end
      end

      def resolve_entry(entry, registry)
        resolve_node(entry.ast, registry, entry)
          .map { entry.with(ast: it) }
          .to_result
      end

      def resolve(node, registry, current_entry)
        resolve_node(node, registry, current_entry)
          .to_result
      end

      def resolve_node(node, registry, current_entry)
        case node
        in AST::Module then Module
        in AST::Implementation then Implementation
        in AST::ImplementationFunction then ImplementationFunction
        in AST::ImportDeclaration then ImportDeclaration
        in AST::InteropImportDeclaration then InteropImportDeclaration
        in AST::Literal then Literal
        in AST::VariableBinding then VariableBinding
        in AST::Body then Body
        in AST::VariableReference then VariableReference
        in AST::ConstructorReference then ConstructorReference
        in AST::FunctionDeclaration then FunctionDeclaration
        in AST::FunctionCall then FunctionCall
        in AST::TypeDeclaration then TypeDeclaration
        in AST::VariantDeclaration then VariantDeclaration
        in AST::IfThenElse then IfThenElse
        in AST::CaseOf then CaseOf
        in AST::CaseOfBranch then CaseOfBranch
        in AST::Pattern::Literal then Pattern::Literal
        in AST::Pattern::Binding then Pattern::Binding
        in AST::Pattern::Wildcard then Pattern::Wildcard
        in AST::Pattern::Constructor then Pattern::Constructor
        in AST::Pattern::Record then Pattern::Record
        in AST::MemberAccess then MemberAccess
        in AST::Lambda then Lambda
        in AST::List then List
        in AST::Grouping then Grouping
        in AST::RecordLiteral then RecordLiteral
        in AST::RecordField then RecordField
        in AST::RecordUpdate then RecordUpdate
        in AST::StructDeclaration then StructDeclaration
        end
          .resolve(node, registry, current_entry)
      end
    end
  end
end

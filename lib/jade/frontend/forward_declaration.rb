require 'jade/frontend/forward_declaration/helper'
require 'jade/frontend/forward_declaration/error'

require 'jade/interop/lowering'

require 'jade/frontend/forward_declaration/body'
require 'jade/frontend/forward_declaration/function_declaration'
require 'jade/frontend/forward_declaration/implementation'
require 'jade/frontend/forward_declaration/implementation_function'
require 'jade/frontend/forward_declaration/import_declaration'
require 'jade/frontend/forward_declaration/interop_import_declaration'
require 'jade/frontend/forward_declaration/module'
require 'jade/frontend/forward_declaration/struct_declaration'
require 'jade/frontend/forward_declaration/type_alias_declaration'
require 'jade/frontend/forward_declaration/type_declaration'
require 'jade/frontend/forward_declaration/interface_declaration'

module Jade
  module Frontend
    module ForwardDeclaration
      extend self

      Result = Data.define(:entry, :errors) do
        def add_errors(new_errors)
          with(errors: errors + new_errors)
        end

        def to_result
          errors.empty? ? Ok[entry] : Err[errors]
        end
      end

      def declare(node, registry, entry)
        shallow_declare_node(node, registry, entry)
          .then { deep_declare_node(node, it.entry, registry).add_errors(it.errors) }
          .to_result
      end

      def declare_entry(entry, registry)
        declare(entry.ast, registry, entry)
      end

      def shallow_declare_node(node, registry, entry)
        resolver(node, entry)
          &.shallow(node, registry, entry) || Result[entry, []]
      end

      def deep_declare_node(node, entry, registry)
        resolver(node, entry)
          &.deep(node, entry, registry) || Result[entry, []]
      end

      private

      def resolver(node, entry)
        case node
        in AST::Body then Body
        in AST::FunctionDeclaration then FunctionDeclaration
        in AST::Implementation then Implementation
        in AST::ImportDeclaration then ImportDeclaration
        in AST::InteropImportDeclaration then InteropImportDeclaration
        in AST::Module then Module
        in AST::StructDeclaration then StructDeclaration
        in AST::TypeAliasDeclaration then TypeAliasDeclaration
        in AST::TypeDeclaration then TypeDeclaration
        in AST::InterfaceDeclaration then InterfaceDeclaration
        else
          nil
        end
      end
    end
  end
end

require 'jade/frontend/forward_declaration/helper'
require 'jade/frontend/forward_declaration/error'

require 'jade/frontend/forward_declaration/body'
require 'jade/frontend/forward_declaration/function_declaration'
require 'jade/frontend/forward_declaration/import_declaration'
require 'jade/frontend/forward_declaration/module'
require 'jade/frontend/forward_declaration/type_declaration'

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
          .then { deep_declare_node(node, it.entry).add_errors(it.errors) }
          .to_result
      end

      def declare_entry(entry, registry)
        declare(entry.ast, registry, entry)
      end

      def shallow_declare_node(node, registry, entry)
        case node
        in AST::Module then Module
        in AST::ImportDeclaration then ImportDeclaration
        in AST::FunctionDeclaration then FunctionDeclaration
        in AST::Body then Body
        in AST::TypeDeclaration then TypeDeclaration
        else
          return Result[entry, []]
        end.shallow(node, registry, entry)
      end

      # TODO: [ForwardDeclaration:HandleErrors]
      def deep_declare_node(node, entry)
        case node
        in AST::Module then Module
        in AST::ImportDeclaration then ImportDeclaration
        in AST::FunctionDeclaration then FunctionDeclaration
        in AST::TypeDeclaration then TypeDeclaration
        in AST::Body then Body
        else
          return Result[entry, []]
        end.deep(node, entry)
      end
    end
  end
end

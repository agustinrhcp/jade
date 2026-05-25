require 'jade/frontend/semantic_analysis/error'

require 'jade/frontend/semantic_analysis/helper'
require 'jade/frontend/semantic_analysis/module_node'
require 'jade/frontend/semantic_analysis/import_declaration'
require 'jade/frontend/semantic_analysis/literal'
require 'jade/frontend/semantic_analysis/char_literal'
require 'jade/frontend/semantic_analysis/assign'
require 'jade/frontend/semantic_analysis/variable_reference'
require 'jade/frontend/semantic_analysis/constructor_reference'
require 'jade/frontend/semantic_analysis/body'
require 'jade/frontend/semantic_analysis/function_declaration'
require 'jade/frontend/semantic_analysis/function_call'
require 'jade/frontend/semantic_analysis/keyed_call/validation'
require 'jade/frontend/semantic_analysis/keyed_call'
require 'jade/frontend/semantic_analysis/type_declaration'
require 'jade/frontend/semantic_analysis/variant_declaration'
require 'jade/frontend/semantic_analysis/interop_import_declaration'
require 'jade/frontend/semantic_analysis/implementation'
require 'jade/frontend/semantic_analysis/implementation_function'
require 'jade/frontend/semantic_analysis/struct_declaration'
require 'jade/frontend/semantic_analysis/interface_declaration'
require 'jade/frontend/semantic_analysis/if_then_else'
require 'jade/frontend/semantic_analysis/member_access'
require 'jade/frontend/semantic_analysis/qualified_access'
require 'jade/frontend/semantic_analysis/record_access'
require 'jade/frontend/semantic_analysis/case_of'
require 'jade/frontend/semantic_analysis/case_of_branch'
require 'jade/frontend/semantic_analysis/pattern_wildcard'
require 'jade/frontend/semantic_analysis/pattern_literal'
require 'jade/frontend/semantic_analysis/pattern_binding'
require 'jade/frontend/semantic_analysis/pattern_constructor'
require 'jade/frontend/semantic_analysis/pattern_record'
require 'jade/frontend/semantic_analysis/pattern_list'
require 'jade/frontend/semantic_analysis/lambda'
require 'jade/frontend/semantic_analysis/grouping'
require 'jade/frontend/semantic_analysis/list'
require 'jade/frontend/semantic_analysis/record_literal'
require 'jade/frontend/semantic_analysis/record_update'
require 'jade/frontend/semantic_analysis/record_field'

module Jade
  module Frontend
    module SemanticAnalysis
      extend self

      def analyze(entry, registry)
        initialize_scope(entry)
          .then { analyze_node(entry.ast, registry, it, entry) }
          .then { it.errors.any? ? Err[it.errors] : Ok[entry.with(ast: it.node)] }
      end

      def analyze_repl(ast, registry, scope, entry)
        analyze_node(ast, registry, scope, entry)
          .then { it.errors.any? ? Err[it.errors] : Ok[[it.node, it.scope]] }
      end

      def analyze_entry(entry, registry)
        analyze(entry, registry)
      end

      private

      def initialize_scope(entry)
        entry
          .values
          .reduce(Scope.new) { |acc, (unq_name, sym)| acc.bind(unq_name, sym) }
      end

      def analyze_node(ast, registry, scope, entry)
        case ast
        in AST::Module then ModuleNode
        in AST::ImportDeclaration then ImportDeclaration
        in AST::InteropImportDeclaration then InteropImportDeclaration
        in AST::Literal then Literal
        in AST::CharLiteral then CharLiteral
        in AST::Assign then Assign
        in AST::VariableReference then VariableReference
        in AST::ConstructorReference then ConstructorReference
        in AST::Body then Body
        in AST::FunctionDeclaration then FunctionDeclaration
        in AST::FunctionCall then FunctionCall
        in AST::KeyedCall then KeyedCall
        in AST::TypeDeclaration then TypeDeclaration
        in AST::VariantDeclaration then VariantDeclaration
        in AST::Implementation then Implementation
        in AST::ImplementationFunction then ImplementationFunction
        in AST::StructDeclaration then StructDeclaration
        in AST::InterfaceDeclaration then InterfaceDeclaration
        in AST::IfThenElse then IfThenElse
        in AST::MemberAccess then MemberAccess
        in AST::QualifiedAccess then QualifiedAccess
        in AST::RecordAccess then RecordAccess
        in AST::CaseOf then CaseOf
        in AST::CaseOfBranch then CaseOfBranch
        in AST::Pattern::Wildcard then PatternWildcard
        in AST::Pattern::Literal then PatternLiteral
        in AST::Pattern::Binding then PatternBinding
        in AST::Pattern::Constructor then PatternConstructor
        in AST::Pattern::Record then PatternRecord
        in AST::Pattern::List then PatternList
        in AST::Lambda then Lambda
        in AST::Grouping then Grouping
        in AST::List then List
        in AST::RecordLiteral then RecordLiteral
        in AST::RecordUpdate then RecordUpdate
        in AST::RecordField then RecordField
        end
          .analyze(ast, registry, scope, entry)
      end

      Result = Data.define(:node, :errors, :scope) do
        def self.init(node, scope)
          new(node:, errors: [], scope:)
        end

        # Combine a fixed set of child Results into a parent Result.
        # `children` keys must match the parent node's `with` field
        # names. Errors are unioned; the parent's `scope:` is whatever
        # the caller decides (usually the input scope or a child's).
        def self.combine(node, scope:, **children)
          new(
            node: node.with(**children.transform_values(&:node)),
            errors: children.values.flat_map(&:errors),
            scope:,
          )
        end

        def add_errors(more)
          with(errors: errors + more)
        end

        def map_node
          with(node: yield(node))
        end

        def with_scope(s)
          with(scope: s)
        end

        def to_result
          errors.any? ? Err[errors] : Ok[node]
        end
      end

      Scope = Data.define(:bindings) do
        def initialize(bindings: {})
          super
        end

        def bind(name, symbol)
          with(bindings: bindings.merge(name => symbol))
        end

        def lookup(name)
          bindings[name]
        end
      end
    end
  end
end

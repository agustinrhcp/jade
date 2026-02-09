require 'jade/frontend/semantic_analysis/error'

require 'jade/frontend/semantic_analysis/helper'
require 'jade/frontend/semantic_analysis/function_declaration'
require 'jade/frontend/semantic_analysis/type_declaration'

module Jade
  module Frontend
    module SemanticAnalyzer
      extend self

      def analyze(entry, registry)
        initialize_scope(entry)
          .then { analyze_r(entry.ast, registry, it) }
          .to_result
          .map { entry }
      end

      def analyze_repl(ast, registry, scope = Scope.new)
        analyze_r(ast, registry, scope)
          .to_result
      end

      private

      def initialize_scope(entry)
        entry
          .values
          .reduce(Scope.new) { |acc, (unq_name, sym)| acc.bind(unq_name, sym) }
      end

      def analyze_r(ast, registry, scope)
        case ast
        in AST::Module(body:, exposing:)
          case exposing 
          in AST::ExposeNone
            Result[
              scope,
              # TODO: Add entry to semantic analysis
              # And add the span to the end of the module name
              [SemanticAnalysis::Error::MissingExposingClause.new(nil, 0..0)]
            ]
          else
            Result[scope, []]
          end
            .then { analyze_r(body, registry, it.scope).add_errors(it.errors) }

        in AST::ImportDeclaration
          Result[scope, []]

        in AST::InteropImportDeclaration
          Result[scope, []]

        in AST::Literal
          Result[scope, []]

        in AST::VariableBinding(name:, expression:)
          analyze_r(expression, registry, scope) => { errors: expr_errors }

          bind(scope, name, Symbol.var(name, ast.range))
            .add_errors(expr_errors)

        in AST::VariableReference(name:)
          lookup(scope, name)

        in AST::ConstructorReference(name:)
          lookup(scope, name)

        in AST::Body(expressions:)
          analyze_many(expressions, registry, scope)

        in AST::FunctionDeclaration(name:, params:, body:, symbol:)
          SemanticAnalysis::FunctionDeclaration.analyze(ast, registry, scope)

        in AST::InfixApplication(left:, right:)
          analyze_r(left, registry, scope) => { errors: l_errors }
          analyze_r(right, registry, scope) => { errors: r_errors }

          Result[scope, l_errors + r_errors]

        in AST::FunctionCall(callee:, args:)
          analyze_many(args, registry, scope) => { errors: args_errors, scope: args_scope }

          analyze_r(callee, registry, scope)
            .add_errors(args_errors)

        in AST::TypeDeclaration(name:, symbol:, variants:)
          SemanticAnalysis::TypeDeclaration.analyze(ast, registry, scope)

        in AST::IfThenElse(condition:, if_branch:, else_branch:)
          analyze_r(condition, registry, scope) => { errors: condition_errors }
          analyze_r(if_branch, registry, scope) => { errors: if_errors }
          analyze_r(else_branch, registry, scope) => { errors: else_errors }

          Result[scope, condition_errors + if_errors + else_errors]

        in AST::QualifiedAccess
          Result[scope, []]

        in AST::RecordAccess
          Result[scope, []]

        in AST::CaseOf(expression:, branches:)
          analyze_r(expression, registry, scope) => { errors: exp_errors }

          analyze_many(branches, registry, scope)
            .add_errors(exp_errors)

        in AST::CaseOfBranch(pattern:, body:)
          analyze_r(pattern, registry, scope) => { scope: ptn_scope, errors: ptn_errors }
          analyze_r(body, registry, ptn_scope) => { errors: body_errors }

          # TODO: Analyze unreachability
          Result[scope, ptn_errors + body_errors]

        in AST::Pattern::Wildcard
          Result[scope, []]

        in AST::Pattern::Literal
          Result[scope, []]

        in AST::Pattern::Binding(name:)
          bind(scope, name, Symbol.var(name, ast.range))

        in AST::Pattern::Constructor(constructor:, patterns:, symbol: sym_ref)
          symbol = registry.lookup(sym_ref)

          if symbol.args.size != patterns.size
            return PaterrnConstructorArityMismatchError
              .new(constructor, symbol.args.size, patterns.size)
              .then { Result[scope, [it]] }
          end

          analyze_many(patterns, registry, scope)

        in AST::Lambda(params:, body:)
          params
            .reduce(Result[scope, []]) do |acc, param|
              bind(acc.scope, param.name, Symbol.param(param.name))
                .add_errors(acc.errors)
            end
            .then do
              analyze_r(body, registry, it.scope)
                .add_errors(it.errors)
            end
            .with(scope:)

        in AST::Grouping(expression:)
          analyze_r(expression, registry, scope)

        in AST::List(items:)
          analyze_many(items, registry, scope)
            .with(scope:)
     
        in AST::RecordLiteral(fields:)
          analyze_many(fields, registry, scope)
            .add_errors(analyze_duplicate_fields(fields))

        in AST::RecordUpdate(base:, fields:)
          analyze_r(base, registry, scope) => { errors: base_errors }

          analyze_many(fields, registry, scope)
            .add_errors(analyze_duplicate_fields(fields))
            .add_errors(base_errors)

        in AST::RecordField(value:)
          analyze_r(value, registry, scope)

        end
      end

      def analyze_many(nodes, registry, scope)
        nodes
          .reduce(Result[scope, []]) do |acc, node|
            analyze_r(node, registry, acc.scope) => Result[node_scope, node_errors]
            Result[node_scope, node_errors + acc.errors]
          end
      end

      def bind(scope, name, symbol)
        if scope.lookup(name)
          Result[scope, [ShadowingError.new(name)]]

        else
          Result[scope.bind(name, symbol), []]
        end
      end

      def lookup(scope, name)
        if scope.lookup(name)
          Result[scope, []]
        else
          UndefinedVariable.new(name)
            .then { Result[scope, [it]] }
        end
      end

      Result = Data.define(:scope, :errors) do
        def to_result
          return Err[errors] if errors.any?

          Ok[scope]
        end

        def add_errors(more_errors)
          with(errors: errors + more_errors)
        end
      end

      Scope = Data.define(:bindings) do
        def initialize(bindings: {})
          super
        end

        def bind(name, symbol)
          with(bindings: bindings.merge(name => symbol))
        end

        def lookup(binding)
          bindings[binding]
        end
      end

      class Error; end
      class ShadowingError < Error
        def initialize(name)
          super()
          @name = name
        end

        def message
          "Variable #{@name} shadows existing variable"
        end
      end

      class UndefinedVariable < Error
        def initialize(var_ref)
          super()
          @var_ref = var_ref
        end

        def message
          "Undefined variable #{@var_ref}"
        end
      end

      class ConstructorPatternArityMismatch < Error
        def initialize(constructor, expected_arity, actual_arity)
          super()
          @constructor = constructor
          @expected_arity = expected_arity
          @actual_arity = actual_arity
        end

        def message
          "Arity mismatch, #{constructor} expects #{expected_arity} patterns but found #{actual_arity}"
        end
      end

      def analyze_duplicate_fields(fields)
        fields
          .group_by(&:key)
          .select { |_, v| v.size > 1 }
          .map do |k, v|
            first, *rest = v
          # TODO: Need to add the entry
            SemanticAnalysis::Error::DuplicateRecordField
              .new(nil, first.range, field_name: k, duplicate_spans: rest.map(&:range))
          end
      end
    end
  end
end

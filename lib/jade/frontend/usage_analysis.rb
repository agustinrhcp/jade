require 'jade/frontend/usage_analysis/reference_index'

module Jade
  module Frontend
    # Walks a resolved AST and builds a ReferenceIndex of where each
    # symbol is used. Runs after SemanticAnalysis (which attaches symbols)
    # and before TypeChecking. Never fails — attaches `usage_index` to
    # the entry and returns it.
    #
    # Reference kinds:
    #   :called          - in callee position of a FunctionCall
    #   :as_value        - bare reference (passed as value, returned, etc.)
    #   :constructed     - constructor applied with args
    #   :pattern_match   - constructor used in a pattern match
    #
    # Type-annotation references are a follow-up (not yet recorded).
    module UsageAnalysis
      extend self

      def analyze(entry, _registry)
        walk(entry.ast, :as_value)
          .group_by(&:symbol_key)
          .freeze
          .then { entry.with(usage_index: ReferenceIndex.new(references: it)) }
      end

      private

      def walk(node, ctx)
        case node
        in AST::Module(body:)
          walk(body, :as_value)

        in AST::Body(expressions:)
          expressions.flat_map { walk(it, :as_value) }

        in AST::FunctionDeclaration(body:)
          walk(body, :as_value)

        in AST::FunctionCall(callee:, args:)
          walk(callee, :called) + args.flat_map { walk(it, :as_value) }

        in AST::VariableReference(symbol:, range:)
          ref(symbol, ctx, range)

        in AST::ConstructorReference(symbol:, range:)
          ref(symbol, ctx == :called ? :constructed : :as_value, range)

        in AST::QualifiedAccess(symbol:, range:)
          ref(symbol, ctx, range)

        in AST::Lambda(body:, params:)
          walk(body, :as_value) + params.flat_map { walk(it, :as_value) }

        in AST::Assign(pattern:, expression:)
          walk(expression, :as_value) + walk(pattern, :as_value)

        in AST::IfThenElse(condition:, if_branch:, else_branch:)
          walk(condition, :as_value) + walk(if_branch, :as_value) + walk(else_branch, :as_value)

        in AST::CaseOf(expression:, branches:)
          walk(expression, :as_value) + branches.flat_map { walk(it, :as_value) }

        in AST::CaseOfBranch(pattern:, body:)
          walk(pattern, :as_value) + walk(body, :as_value)

        in AST::Pattern::Constructor(constructor:, patterns:, symbol:)
          # Don't walk `constructor` — it's a bare ConstructorReference
          # and walking it would record a spurious :as_value for every
          # pattern match.
          ref(symbol, :pattern_match, constructor.range) +
            patterns.flat_map { walk(it, :as_value) }

        in AST::Pattern::List(patterns:, rest:)
          rest_refs = rest ? walk(rest, :as_value) : []
          patterns.flat_map { walk(it, :as_value) } + rest_refs

        in AST::Pattern::Record(fields:)
          fields.flat_map { walk(it.pattern, :as_value) }

        in AST::Pattern::Literal | AST::Pattern::Binding | AST::Pattern::Wildcard
          []

        in AST::Grouping(expression:)
          walk(expression, ctx)

        in AST::List(items:)
          items.flat_map { walk(it, :as_value) }

        in AST::RecordLiteral(fields:)
          fields.flat_map { walk(it, :as_value) }

        in AST::RecordUpdate(base:, fields:)
          walk(base, :as_value) + fields.flat_map { walk(it, :as_value) }

        in AST::RecordField(value:)
          walk(value, :as_value)

        in AST::RecordAccess(target:)
          walk(target, :as_value)

        in AST::Implementation(functions:)
          functions.flat_map { walk(it, :as_value) }

        in AST::ImplementationFunction(fn:)
          walk(fn, :as_value)

        in AST::Literal | AST::CharLiteral |
           AST::ImportDeclaration | AST::InteropImportDeclaration |
           AST::TypeDeclaration | AST::VariantDeclaration |
           AST::StructDeclaration | AST::InterfaceDeclaration |
           AST::MemberAccess | AST::KeyedCall
          # No value-level references to record. KeyedCall and
          # MemberAccess are both lowered away during semantic_analysis,
          # so the branch is defensive against partial ASTs.
          []
        end
      end

      def ref(symbol, kind, range)
        [Reference[ReferenceIndex.key_for(symbol), kind, range]]
      end
    end
  end
end

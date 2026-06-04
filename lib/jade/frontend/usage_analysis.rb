require 'jade/frontend/usage_analysis/reference_index'

module Jade
  module Frontend
    # Walks a resolved AST and builds a ReferenceIndex of where each
    # symbol is used. Runs after SemanticAnalysis (which attaches symbols)
    # and before TypeChecking. Never fails — attaches `usage_index` to
    # the entry and returns it.
    #
    # Reference kinds:
    #   :called           - in callee position of a FunctionCall
    #   :as_value         - bare reference (passed as value, returned, etc.)
    #   :constructed      - constructor applied with args
    #   :pattern_match    - constructor used in a pattern match
    #   :type_annotation  - type appearing in a signature, variant args,
    #                       struct fields, interface signatures, etc.
    #   :exposed          - name listed in `module M exposing (...)`
    module UsageAnalysis
      extend self

      def analyze(entry, _registry)
        walk(entry.ast, :as_value, entry)
          .group_by(&:symbol_key)
          .freeze
          .then { entry.with(usage_index: ReferenceIndex.new(references: it)) }
      end

      private

      def walk(node, ctx, entry)
        case node
        in AST::Module(exposing:, body:)
          walk_exposing(exposing, entry) + walk(body, :as_value, entry)

        in AST::Body(expressions:)
          expressions.flat_map { walk(it, :as_value, entry) }

        in AST::FunctionDeclaration(body:, params:, return_type:)
          walk(body, :as_value, entry) +
            params.flat_map { walk_type(it.type, entry) } +
            walk_type(return_type, entry)

        in AST::FunctionCall(callee:, args:)
          walk(callee, :called, entry) + args.flat_map { walk(it, :as_value, entry) }

        in AST::VariableReference(symbol:, range:)
          ref(symbol, ctx, range)

        in AST::ConstructorReference(symbol:, range:)
          ref(symbol, ctx == :called ? :constructed : :as_value, range)

        in AST::QualifiedAccess(symbol:, range:)
          ref(symbol, ctx, range)

        in AST::Lambda(body:, params:)
          walk(body, :as_value, entry) +
            params.flat_map { walk(it, :as_value, entry) }

        in AST::Assign(pattern:, expression:)
          walk(expression, :as_value, entry) + walk(pattern, :as_value, entry)

        in AST::IfThenElse(condition:, if_branch:, else_branch:)
          walk(condition, :as_value, entry) +
            walk(if_branch, :as_value, entry) +
            walk(else_branch, :as_value, entry)

        in AST::CaseOf(expression:, branches:)
          walk(expression, :as_value, entry) +
            branches.flat_map { walk(it, :as_value, entry) }

        in AST::CaseOfBranch(pattern:, body:)
          walk(pattern, :as_value, entry) + walk(body, :as_value, entry)

        in AST::Pattern::Constructor(constructor:, patterns:, symbol:)
          # Don't walk `constructor` — it's a bare ConstructorReference
          # and walking it would record a spurious :as_value for every
          # pattern match.
          ref(symbol, :pattern_match, constructor.range) +
            patterns.flat_map { walk(it, :as_value, entry) }

        in AST::Pattern::List(patterns:, rest:)
          rest_refs = rest ? walk(rest, :as_value, entry) : []
          patterns.flat_map { walk(it, :as_value, entry) } + rest_refs

        in AST::Pattern::Record(fields:)
          fields.flat_map { walk(it.pattern, :as_value, entry) }

        in AST::Pattern::Literal | AST::Pattern::Binding | AST::Pattern::Wildcard
          []

        in AST::Grouping(expression:)
          walk(expression, ctx, entry)

        in AST::List(items:)
          items.flat_map { walk(it, :as_value, entry) }

        in AST::RecordLiteral(fields:)
          fields.flat_map { walk(it, :as_value, entry) }

        in AST::RecordUpdate(base:, fields:)
          walk(base, :as_value, entry) + fields.flat_map { walk(it, :as_value, entry) }

        in AST::RecordField(value:)
          walk(value, :as_value, entry)

        in AST::RecordAccess(target:)
          walk(target, :as_value, entry)

        in AST::Implementation(applied_type:, functions:)
          walk_type(applied_type, entry) +
            functions.flat_map { walk(it, :as_value, entry) }

        in AST::ImplementationFunction(fn:)
          walk(fn, :as_value, entry)

        in AST::TypeDeclaration(variants:)
          variants.flat_map { it.args.flat_map { walk_type(it, entry) } }

        in AST::StructDeclaration(record_type:)
          walk_type(record_type, entry)

        in AST::InterfaceDeclaration(functions:)
          functions.flat_map { walk_type(it.type, entry) }

        in AST::InteropImportDeclaration(functions:)
          functions.flat_map { walk_type(it.type, entry) }

        in AST::ImportDeclaration | AST::VariantDeclaration |
           AST::Literal | AST::CharLiteral |
           AST::MemberAccess | AST::KeyedCall
          # ImportDeclaration's exposing list is handled when we land
          # in importer modules — see walk_exposing. KeyedCall and
          # MemberAccess are lowered away during semantic_analysis, so
          # the branches are defensive against partial ASTs.
          []
        end
      end

      def walk_type(node, entry)
        case node
        in nil
          []

        in AST::TypeName(type:, range:)
          entry.types[type]
            .then { it ? [Reference[ReferenceIndex.key_for(it), :type_annotation, range]] : [] }

        in AST::TypeApplication(constructor:, args:)
          walk_type(constructor, entry) + args.flat_map { walk_type(it, entry) }

        in AST::TypeFunction(params:, return_type:)
          params.flat_map { walk_type(it, entry) } + walk_type(return_type, entry)

        in AST::TypeRecord(fields:)
          fields.values.flat_map { walk_type(it, entry) }

        in AST::TypeTuple(items:)
          items.flat_map { walk_type(it, entry) }

        in AST::TypeVar | AST::TypeUnit | AST::QualifiedTypeName |
           AST::TypeParam
          []
        end
      end

      def walk_exposing(node, entry)
        case node
        in AST::ExposeList(items:)
          items.flat_map { walk_expose_item(it, entry) }

        in AST::ExposeAll | AST::ExposeNone
          []
        end
      end

      def walk_expose_item(item, entry)
        case item
        in AST::ExposeValue(name:, range:)
          exposed_ref(entry.lookup_value(name), range)

        in AST::ExposeType | AST::ExposeTypeExpand
          exposed_ref(entry.lookup_type(item.name), item.range)
        end
      end

      def exposed_ref(symbol, range)
        symbol ? [Reference[ReferenceIndex.key_for(symbol), :exposed, range]] : []
      end

      def ref(symbol, kind, range)
        [Reference[ReferenceIndex.key_for(symbol), kind, range]]
      end
    end
  end
end

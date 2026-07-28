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
    #
    # Every reference also carries the `owner` it was made from — see
    # ReferenceIndex. Only `:exposed` has none.
    module UsageAnalysis
      extend self

      def analyze(entry, _registry)
        walk(entry.ast, :as_value, entry, nil)
          .group_by(&:symbol_key)
          .freeze
          .then { entry.with(usage_index: ReferenceIndex.new(references: it)) }
      end

      private

      # `owner` is the key of the enclosing declaration or implementation,
      # threaded down rather than recovered afterwards by range
      # containment: desugared nodes carry `range == nil`, and references
      # inside an `implements` block sit in no declaration's span, so
      # both are unbucketable.
      def walk(node, ctx, entry, owner)
        case node
        in AST::Module(exposing:, body:)
          walk_exposing(exposing, entry) + walk(body, :as_value, entry, owner)

        in AST::Body(expressions:)
          expressions.flat_map { walk(it, :as_value, entry, owner) }

        in AST::FunctionDeclaration(body:, params:, return_type:, symbol:)
          ReferenceIndex.key_for(symbol).then do |declared|
            walk(body, :as_value, entry, declared) +
              params.flat_map { walk_type(it.type, entry, declared) } +
              walk_type(return_type, entry, declared)
          end

        in AST::FunctionCall(callee:, args:)
          walk(callee, :called, entry, owner) +
            args.flat_map { walk(it, :as_value, entry, owner) }

        in AST::VariableReference(symbol:, range:)
          ref(symbol, ctx, range, owner)

        in AST::ConstructorReference(symbol:, range:)
          ref(symbol, ctx == :called ? :constructed : :as_value, range, owner)

        in AST::QualifiedAccess(symbol:, range:)
          ref(symbol, ctx, range, owner)

        in AST::Lambda(body:, params:)
          walk(body, :as_value, entry, owner) +
            params.flat_map { walk(it, :as_value, entry, owner) }

        in AST::Assign(pattern:, expression:)
          walk(expression, :as_value, entry, owner) +
            walk(pattern, :as_value, entry, owner)

        in AST::IfThenElse(condition:, if_branch:, else_branch:)
          walk(condition, :as_value, entry, owner) +
            walk(if_branch, :as_value, entry, owner) +
            walk(else_branch, :as_value, entry, owner)

        in AST::CaseOf(expression:, branches:)
          walk(expression, :as_value, entry, owner) +
            branches.flat_map { walk(it, :as_value, entry, owner) }

        in AST::CaseOfBranch(pattern:, body:)
          walk(pattern, :as_value, entry, owner) + walk(body, :as_value, entry, owner)

        in AST::Pattern::Constructor(constructor:, patterns:, symbol:)
          # Don't walk `constructor` — it's a bare ConstructorReference
          # and walking it would record a spurious :as_value for every
          # pattern match.
          ref(symbol, :pattern_match, constructor.range, owner) +
            patterns.flat_map { walk(it, :as_value, entry, owner) }

        in AST::Pattern::List(patterns:, rest:)
          rest_refs = rest ? walk(rest, :as_value, entry, owner) : []
          patterns.flat_map { walk(it, :as_value, entry, owner) } + rest_refs

        in AST::Pattern::Record(fields:)
          fields.flat_map { walk(it.pattern, :as_value, entry, owner) }

        in AST::Pattern::Literal | AST::Pattern::Binding | AST::Pattern::Wildcard
          []

        in AST::Grouping(expression:)
          walk(expression, ctx, entry, owner)

        in AST::List(items:)
          items.flat_map { walk(it, :as_value, entry, owner) }

        in AST::RecordLiteral(fields:)
          fields.flat_map { walk(it, :as_value, entry, owner) }

        in AST::RecordUpdate(base:, fields:)
          walk(base, :as_value, entry, owner) +
            fields.flat_map { walk(it, :as_value, entry, owner) }

        in AST::RecordField(value:)
          walk(value, :as_value, entry, owner)

        in AST::RecordAccess(target:)
          walk(target, :as_value, entry, owner)

        in AST::Implementation(applied_type:, functions:, symbol:)
          # `implements X with f: <lambda>` has no enclosing declaration,
          # so the implementation itself owns what its functions call.
          ReferenceIndex.key_for(symbol).then do |impl|
            walk_type(applied_type, entry, impl) +
              functions.flat_map { walk(it, :as_value, entry, impl) }
          end

        in AST::ImplementationFunction(fn:)
          walk(fn, :as_value, entry, owner)

        in AST::TypeDeclaration(variants:, symbol:)
          ReferenceIndex.key_for(symbol).then do |declared|
            variants.flat_map { it.args.flat_map { walk_type(it, entry, declared) } }
          end

        in AST::StructDeclaration(record_type:, symbol:)
          walk_type(record_type, entry, ReferenceIndex.key_for(symbol))

        in AST::InterfaceDeclaration(functions:, symbol:)
          ReferenceIndex.key_for(symbol).then do |declared|
            functions.flat_map { walk_type(it.type, entry, declared) }
          end

        in AST::InteropImportDeclaration(functions:)
          # Owned per port, not per `uses` block — the port is what a
          # caller names and what carries the effect boundary.
          functions.flat_map { walk_type(it.type, entry, ReferenceIndex.key_for(it.symbol)) }

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

      def walk_type(node, entry, owner)
        case node
        in nil
          []

        in AST::TypeName(type:, range:)
          entry.types[type]
            .then { it ? ref(it, :type_annotation, range, owner) : [] }

        in AST::TypeApplication(constructor:, args:)
          walk_type(constructor, entry, owner) +
            args.flat_map { walk_type(it, entry, owner) }

        in AST::TypeFunction(params:, return_type:)
          params.flat_map { walk_type(it, entry, owner) } +
            walk_type(return_type, entry, owner)

        in AST::TypeRecord(fields:)
          fields.values.flat_map { walk_type(it, entry, owner) }

        in AST::TypeTuple(items:)
          items.flat_map { walk_type(it, entry, owner) }

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

      # The exposing list is module level, so these have no owner.
      def exposed_ref(symbol, range)
        symbol ? ref(symbol, :exposed, range, nil) : []
      end

      def ref(symbol, kind, range, owner)
        [Reference[ReferenceIndex.key_for(symbol), kind, range, owner]]
      end
    end
  end
end

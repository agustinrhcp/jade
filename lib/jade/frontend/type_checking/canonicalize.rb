module Jade
  module Frontend
    module TypeChecking
      # Finalize-time pass that rewrites attached dictionary markers in place
      # through the final substitution. Codegen then reads marker.type.id
      # directly — dict_env keys (built from scheme.constraints) and marker
      # ids both pass through the same final substitution, so they match.
      #
      # We do NOT pre-substitute scheme.type/constraints: substitution can map
      # one quantified var to another (e.g. `b → c'` via body unification),
      # which would leave the scheme's `quantified` list and type out of sync
      # for downstream instantiations.
      module Canonicalize
        extend self

        def run(ast, env)
          walk(ast, env.substitution)
          env
        end

        private

        def walk(node, sub)
          case node
          in AST::FunctionCall(callee:, args:)
            canonicalize_dictionaries(node, sub)
            walk(callee, sub)
            args.each { walk(it, sub) }

          in AST::QualifiedAccess | AST::VariableReference
            canonicalize_dictionaries(node, sub)

          in AST::Module(body:)             then walk(body, sub)
          in AST::Body(expressions:)        then expressions.each { walk(it, sub) }
          in AST::FunctionDeclaration(body:) then walk(body, sub)
          in AST::Implementation(functions:) then functions.each { walk(it, sub) }
          in AST::ImplementationFunction(fn:) then walk(fn, sub)
          in AST::Assign(expression:)       then walk(expression, sub)
          in AST::Lambda(body:)             then walk(body, sub)
          in AST::Grouping(expression:)     then walk(expression, sub)
          in AST::List(items:)              then items.each { walk(it, sub) }
          in AST::RecordLiteral(fields:)    then fields.each { walk(it, sub) }
          in AST::RecordField(value:)       then walk(value, sub)
          in AST::RecordUpdate(base:, fields:)
            walk(base, sub)
            fields.each { walk(it, sub) }
          in AST::RecordAccess(target:)     then walk(target, sub)
          in AST::IfThenElse(condition:, if_branch:, else_branch:)
            walk(condition, sub)
            walk(if_branch, sub)
            walk(else_branch, sub)
          in AST::CaseOf(expression:, branches:)
            walk(expression, sub)
            branches.each { walk(it, sub) }
          in AST::CaseOfBranch(body:)       then walk(body, sub)

          # Leaves: cannot contain a FunctionCall. Listed explicitly so
          # adding a new node type forces a decision here rather than
          # silently skipping a subtree.
          in AST::Literal |
             AST::CharLiteral |
             AST::ConstructorReference |
             AST::ImportDeclaration |
             AST::InteropImportDeclaration |
             AST::TypeDeclaration |
             AST::StructDeclaration |
             AST::InterfaceDeclaration |
             AST::Placeholder
            nil
          end
        end

        # If the marker's var substituted to a concrete type (e.g. a call
        # inside a non-polymorphic body where the type was a Var at attach
        # time but later unified to Int), leave the marker alone. Codegen's
        # dict_env lookup will miss and the call site falls back to runtime
        # dispatch, matching the pre-canonicalize behavior.
        def canonicalize_dictionaries(node, sub)
          node.dictionaries.each_with_index do |entry, i|
            next unless entry.is_a?(Type::Constraint)

            applied = sub.apply(entry.type)
            next unless applied.is_a?(Type::Var)

            node.dictionaries[i] = entry.with(type: applied)
          end
        end
      end
    end
  end
end

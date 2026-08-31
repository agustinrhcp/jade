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

        def run(ast, env, registry)
          walk(ast, env.substitution, registry, env.entry_name)
          env
        end

        private

        def walk(node, sub, registry, entry_name)
          case node
          in AST::FunctionCall(callee:, args:)
            canonicalize_dictionaries(node, sub, registry, entry_name)
            walk(callee, sub, registry, entry_name)
            args.each { walk(it, sub, registry, entry_name) }

          in AST::QualifiedAccess | AST::VariableReference
            canonicalize_dictionaries(node, sub, registry, entry_name)

          in AST::Module(body:)             then walk(body, sub, registry, entry_name)
          in AST::Body(expressions:)        then expressions.each { walk(it, sub, registry, entry_name) }
          in AST::FunctionDeclaration(body:) then walk(body, sub, registry, entry_name)
          in AST::Implementation(functions:) then functions.each { walk(it, sub, registry, entry_name) }
          in AST::ImplementationFunction(fn:) then walk(fn, sub, registry, entry_name)
          in AST::Assign(expression:)       then walk(expression, sub, registry, entry_name)
          in AST::Lambda(body:)             then walk(body, sub, registry, entry_name)
          in AST::Grouping(expression:)     then walk(expression, sub, registry, entry_name)
          in AST::List(items:)              then items.each { walk(it, sub, registry, entry_name) }
          in AST::RecordLiteral(fields:)    then fields.each { walk(it, sub, registry, entry_name) }
          in AST::RecordField(value:)       then walk(value, sub, registry, entry_name)
          in AST::RecordUpdate(base:, fields:)
            walk(base, sub, registry, entry_name)
            fields.each { walk(it, sub, registry, entry_name) }
          in AST::RecordAccess(target:)     then walk(target, sub, registry, entry_name)
          in AST::IfThenElse(condition:, if_branch:, else_branch:)
            walk(condition, sub, registry, entry_name)
            walk(if_branch, sub, registry, entry_name)
            walk(else_branch, sub, registry, entry_name)
          in AST::CaseOf(expression:, branches:)
            walk(expression, sub, registry, entry_name)
            branches.each { walk(it, sub, registry, entry_name) }
          in AST::CaseOfBranch(body:)       then walk(body, sub, registry, entry_name)

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
             AST::TypeAliasDeclaration |
             AST::InterfaceDeclaration |
             AST::Placeholder
            nil
          end
        end

        # Rewrite var-typed dictionary markers through the final substitution.
        # If the var resolved to a concrete type (e.g. `Decodable α` where a
        # pattern-binding unified α with Int), resolve the impl now so codegen
        # can dispatch directly — previously this only handled var-stayed-var
        # and the substituted-to-concrete case crashed codegen's dict lookup.
        def canonicalize_dictionaries(node, sub, registry, entry_name)
          node.dictionaries.each_with_index do |entry, i|
            next unless entry.is_a?(Type::Constraint)

            applied = sub.apply(entry.type)
            resolved = entry.with(type: applied)

            if applied.is_a?(Type::Var)
              node.dictionaries[i] = resolved
            else
              Constraints
                .resolve(resolved, registry, entry_name)
                .map { node.dictionaries[i] = it }
            end
          end
        end
      end
    end
  end
end

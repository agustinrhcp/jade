module Jade
  module Frontend
    module Desugaring
      extend self

      def desugar_entry(entry)
        desugar(entry.ast)
          .then { entry.with(ast: it) }
      end

      def desugar(node)
        case node
        in AST::Module(body:)
          node.with(body: desugar(body))

        in AST::Body(expressions:)
          expressions
            .map { desugar(it) }
            .then { node.with(expressions: it) }

        in AST::InfixApplication(left:, right:, operator:)
          case operator

          in AST::InfixOperator(value: '|>')
            case right
            in AST::FunctionCall(args:)
              right
                .with(args: [left] + args)
                .then { desugar(it) }

            else
              AST::FunctionCall[right, [left], node.range]
            end
              .then { desugar(it) }

          else
            node
              .with(right: desugar(right))
              .with(left: desugar(left))
          end

        in AST::FunctionCall(callee:, args:)
          node
            .with(callee: desugar(callee))
            .with(args: args.map { desugar(it) })

        in AST::FunctionDeclaration(body:)
          node
            .with(body: desugar(body))

        in AST::MemberAccess(target:)
          node
            .with(target: desugar(target))

        in AST::CaseOf(expression:, branches:)
          node
            .with(expression: desugar(expression))
            .with(branches: branches.map { desugar(it) })

        in AST::CaseOfBranch(pattern:, body:)
          node
            .with(pattern: desugar(pattern))
            .with(body: desugar(body))

        in AST::IfThenElse(condition:, if_branch:, else_branch:)
          node
            .with(condition: desugar(condition))
            .with(if_branch: desugar(if_branch))
            .with(else_branch: desugar(else_branch))

        in AST::VariableBinding(expression:)
          node.with(expression: desugar(expression))

        in AST::Grouping(expression:)
          node.with(expression: desugar(expression))

        in AST::Lambda(body:)
          node.with(body: desugar(body))

        in AST::Literal | AST::VariableReference | AST::ConstructorReference |
          AST::TypeDeclaration | AST::ImportDeclaration | AST::Pattern::Constructor |
          AST::Pattern::Literal | AST::Pattern::Binding | AST::Pattern::Wildcard

          node
        end
      end
    end
  end
end

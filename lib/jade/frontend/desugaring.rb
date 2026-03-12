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
              AST::FunctionCall[right, [left], true, nil, node.range]

            end
              .then { desugar(it) }

          else
            AST::FunctionCall[
              AST::VariableReference["(#{operator.value})", operator.range],
              [desugar(left), desugar(right)],
              operator,
              nil,
              node.range
            ]
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

        in AST::List(items:)
          node
            .with(items: items.map { desugar(it) })

        in AST::RecordLiteral(fields:)
          fields.map { desugar(it) }.then { node.with(fields: it) }

        in AST::RecordUpdate(fields:)
          fields.map { desugar(it) }.then { node.with(fields: it) }

        in AST::RecordField(value:)
          desugar(value).then { node.with(value: it) }

        in AST::RecordAccessSugar(field_key:, range:)
          AST::VariableReference['x', nil]
            .then { AST::MemberAccess[it, AST::VariableReference[field_key, nil], range] }
            .then { AST::Body[[it], nil] }
            .then { AST::Lambda[[AST::LambdaParam['x', nil]], it, range] }

        in AST::RecordUpdateSugar(field_key:, range:)
          value_reference = AST::VariableReference['value', nil]

          AST::VariableReference['x', nil]
            .then { AST::RecordUpdate[it, [AST::RecordField[field_key, value_reference, nil]], range] }
            .then { AST::Body[[it], nil] }
            .then do |body|
              AST::Lambda[
                [AST::LambdaParam['x', nil], AST::LambdaParam[value_reference.name, nil]],
                body,
                range,
              ]
            end

        in AST::Literal | AST::VariableReference | AST::ConstructorReference |
          AST::TypeDeclaration | AST::ImportDeclaration | AST::Pattern::Constructor |
          AST::Pattern::Literal | AST::Pattern::Binding | AST::Pattern::Wildcard |
          AST::Pattern::Record | AST::InteropImportDeclaration | AST::StructDeclaration

          node
        end
      end
    end
  end
end

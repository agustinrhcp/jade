require 'jade/frontend/desugaring/placeholder'

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
          node.with(expressions: desugar_expressions(expressions))

        in AST::InfixApplication(left:, right:, operator:)
          case operator
          in AST::InfixOperator(value: '|>')
            case right
            in AST::FunctionCall(args:)
              right
                .with(args: [left] + args)
                .then { desugar(it) }

            else
              AST::FunctionCall.new(
                callee: right,
                args: [left],
                infix: operator,
                range: node.range,
              )

            end
              .then { desugar(it) }

          else
            AST::FunctionCall.new(
              callee: AST::VariableReference["(#{operator.value})", operator.range],
              args: [desugar(left), desugar(right)],
              infix: operator,
              range: node.range,
            )
          end

        in AST::FunctionCall(callee:, args:)
          node
            .with(callee: desugar(callee))
            .with(args: args.map { desugar(it) })
            .then { Placeholder.lift(it) }

        in AST::KeyedCall(callee:, fields:)
          node
            .with(callee: desugar(callee))
            .with(fields: fields.map { desugar(it) })

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

        in AST::Assign(pattern:, expression:)
          node.with(pattern: desugar(pattern), expression: desugar(expression))

        in AST::Grouping(expression:)
          node.with(expression: desugar(expression))

        in AST::Lambda(params:, body:)
          node
            .with(params: params.map { desugar(it) })
            .with(body: desugar(body))

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
            .then { AST::Lambda[[AST::Pattern::Binding['x', nil]], it, range] }

        in AST::RecordUpdateSugar(field_key:, range:)
          value_reference = AST::VariableReference['value', nil]

          AST::VariableReference['x', nil]
            .then { AST::RecordUpdate[it, [AST::RecordField[field_key, value_reference, nil]], range] }
            .then { AST::Body[[it], nil] }
            .then do |body|
              AST::Lambda[
                [
                  AST::Pattern::Binding['x', nil],
                  AST::Pattern::Binding[value_reference.name, nil],
                ],
                body,
                range,
              ]
            end

        in AST::Tuple(items:)
          AST::FunctionCall.new(
            callee: AST::ConstructorReference["Tuple.Tuple#{items.size}", node.range],
            args: items.map { desugar(it) },
            infix: false,
            range: node.range,
          )

        in AST::Pattern::Tuple(patterns:)
          AST::ConstructorReference[
            "Tuple.Tuple#{patterns.size}",
            node.range,
          ]
            .then do
              AST::Pattern::Constructor.new(
                constructor: it,
                patterns: patterns.map { desugar(it) },
                range: node.range,
              )
            end

        in AST::Pattern::Constructor(patterns:)
          node.with(patterns: patterns.map { desugar(it) })

        in AST::Pattern::Record(fields:)
          fields
            .map { it.with(pattern: desugar(it.pattern)) }
            .then { node.with(fields: it) }

        in AST::Pattern::List(patterns:, rest:)
          node
            .with(patterns: patterns.map { desugar(it) })
            .with(rest: rest && desugar(rest))

        in AST::Implementation(functions:)
          functions
            .map { desugar(it) }
            .then { node.with(functions: it) }

        in AST::ImplementationFunction(fn:)
          node.with(fn: desugar(fn))

        in AST::Literal | AST::CharLiteral | AST::VariableReference | AST::ConstructorReference |
          AST::TypeDeclaration | AST::ImportDeclaration |
          AST::Pattern::Literal | AST::Pattern::Binding | AST::Pattern::Wildcard |
          AST::Pattern::Record | AST::InteropImportDeclaration | AST::StructDeclaration |
          AST::QualifiedAccess | AST::Placeholder | AST::InterfaceDeclaration

          node
        end
      end

      private

      def desugar_expressions(expressions)
        case expressions
        in [AST::Bind(pattern:, expression: expr, range: bind_range), *rest]
          AST::Lambda[
            [pattern],
            AST::Body[rest, nil],
            nil,
          ]
            .then { [expr, it] }
            .map { desugar(it) }
            .then do
              AST::FunctionCall.new(
                callee:       AST::VariableReference['and_then', nil],
                args:         it,
                infix:        false,
                dictionaries: [],
                range:        bind_range,
              )
            end
            .then { [it] }

        in [expr, *rest]
          [desugar(expr)] + desugar_expressions(rest)

        in []
          []
        end
      end

    end
  end
end

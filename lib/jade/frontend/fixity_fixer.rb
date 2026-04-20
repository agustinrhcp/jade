module Jade
  module Frontend
    module FixityFixer
      extend self

      module SplitWhen
        refine Enumerable do
          def split_when
            i = self.index { |x| !yield(x) } || self.length
            [self.take(i), self.drop(i)]
          end
        end
      end

      using SplitWhen

      Fixity = Data.define(:precedence, :assoc) do
        # Compare the rank of two operators for shunting-yard purposes
        # Returns:
        #   - negative if self has lower rank
        #   - zero if self and other are equal rank
        #   - positive if self has higher rank
        def <=>(other)
          # rank by precedence first
          prec_cmp = precedence <=> other.precedence
          return prec_cmp unless prec_cmp.zero?

          # same precedence → rank by associativity
          case assoc
          when :left
            0   # equal rank: left-assoc
          when :right
            1   # higher rank: right-assoc
          when :none
            raise "Non-associative operator cannot be chained"
          end
        end
      end

      FIXITY = {
        '+'  => Fixity[6, :left],
        '-'  => Fixity[6, :left],
        '*'  => Fixity[7, :left],
        '/'  => Fixity[7, :left],
        '|>' => Fixity[2, :left],
        '<|' => Fixity[2, :right],
        '==' => Fixity[4, :none],
        '!=' => Fixity[4, :none],
        '<=' => Fixity[4, :none],
        '>=' => Fixity[4, :none],
        '>'  => Fixity[4, :none],
        '<'  => Fixity[4, :none],
        '&&'  => Fixity[3, :right],
        '||'  => Fixity[3, :right],
      }.freeze

      def fix_entry(entry)
        fix(entry.ast)
          .then { entry.with(ast: it) }
      end

      def fix(node)
        case node
        in AST::Module(body:)
          fix(body)
            .then { node.with(body: it) }

        in AST::InfixApplication
          flatten(node)
            .then { shunting_yard(it) }
            .then { unflatten(it) }

        in AST::VariableBinding(expression:)
          node.with(expression: fix(expression))

        in AST::FunctionDeclaration(body:)
          node.with(body: fix(body))

        in AST::Body(expressions:)
          expressions
            .map { fix(it) }
            .then { node.with(expressions: it) } 

        in AST::FunctionCall(callee:, args:)
          args
            .map { fix(it) }
            .then { node.with(args: it, callee: fix(callee)) }

        in AST::MemberAccess(target:)
          fix(target)
            .then { node.with(target: it) }

        in AST::CaseOf(expression:, branches:)
          branches.map { fix(it) }
            .then { node.with(branches:, expression: fix(expression)) }

        in AST::CaseOfBranch(body:)
          node.with(body: fix(body))

        in AST::IfThenElse(condition:, if_branch:, else_branch:)
          node.with(
            condition: fix(condition),
            if_branch: fix(if_branch),
            else_branch: fix(else_branch),
          )

        in AST::Lambda(body:)
          node.with(body: fix(body))

        in AST::ImplementationFunction(fn:)
          node.with(fn: fix(fn))

        in AST::Implementation(functions:)
          functions
            .map { fix(it) }
            .then { node.with(functions: it) }

        in AST::Grouping(expression:)
          node.with(expression: fix(expression))

        in AST::List(items:)
          items
            .map { fix(it) }
            .then { node.with(items: it) }

        in AST::RecordLiteral(fields:)
          fields.map { fix(it) }.then { node.with(fields: it) }

        in AST::RecordField(value:)
          fix(value).then { node.with(value: it) }

        in AST::RecordUpdate(fields:)
          fields.map { fix(it) }.then { node.with(fields: it) }

        in AST::Tuple(items:)
          items.map { fix(it) }.then { node.with(items: it) }

        in AST::Bind(expression:)
          node.with(expression: fix(expression))

        in AST::VariableReference | AST::ConstructorReference | AST::TypeDeclaration |
          AST::ImportDeclaration | AST::Literal | AST::RecordAccessSugar | AST::InteropImportDeclaration |
          AST::StructDeclaration

          node
        end
      end

      private

      def flatten(ast)
        case ast
        in AST::InfixApplication(left:, operator:, right:)
          flatten(left) + [operator] + flatten(right)

        else
          [ast]
        end
      end

      def shunting_yard(flat_infix)
        flat_infix
          .reduce([[], []]) do |(output, stack), node|
            case node
            in AST::InfixOperator(value:)
              to_pop, to_keep = stack
                .reverse
                .split_when do |op|
                  (FIXITY[value] <=> FIXITY[op.value]) <= 0
                end

              [output + to_pop, to_keep.reverse + [node]]

            else
              [output + [node], stack]
            end
          end
          .then { |(output, stack)| output + stack.reverse }
      end

      def unflatten(npr)
        npr
          .reduce([]) do |stack, node|
            case node
            in AST::InfixOperator
              *rest, left, right = stack
              AST
                .infix_application.call(left, node, right)
                .then { rest + [it] }

            else
              stack + [node]
            end
          end
          .first
      end
    end
  end
end

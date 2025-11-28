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
        '+' => Fixity[6, :left],
        '-' => Fixity[6, :left],
        '*' => Fixity[7, :left],
        '/' => Fixity[7, :left],
      }.freeze

      def fix_entry(entry)
        fix(entry.ast)
          .then { entry.with(ast: it) }
      end

      def fix(ast)
        case ast
        in AST::InfixApplication
          flatten(ast)
            .then { shunting_yard(it) }
            .then { unflatten(it) }

        in AST::VariableBinding(expression:)
          ast.with(expression: fix(expression))

        in AST::FunctionDeclaration(body:)
          ast.with(body: fix(body))

        in AST::Body(expressions:)
          expressions
            .map { fix(it) }
            .then { ast.with(expressions: it) } 

        else
          ast
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

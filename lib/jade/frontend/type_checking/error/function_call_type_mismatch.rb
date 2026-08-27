module Jade
  module Frontend
    module TypeChecking
      module Error
        class FunctionCallTypeMismatch < TypeMismatch
          def initialize(entry, span, expected:, actual:, infix:, lifted_placeholder:)
            super
            @infix = infix
            @lifted_placeholder = lifted_placeholder
          end

          def message
            case @infix
            in AST::InfixOperator(value:)
              infix_error(value)
            else
              "Function call mismatch, expected #{naming[@expected]} but found #{naming[@actual]}"
            end
          end

          def notes
            return [] unless one_too_many_with_a_hole?

            [Jade::Diagnostics::Annotation[
              :help,
              'a `_` makes this a function of the hole, and the call has one ' \
                'argument too many for that. If you piped into it, `|>` ' \
                'already supplies the first argument, so drop the `_`',
            ]]
          end

          private

          # `xs |> f(_, y)` reads as though the `_` marks where the piped
          # value goes, but `|>` has already put it in front of it.
          def one_too_many_with_a_hole?
            return false unless @lifted_placeholder
            return false unless @expected in Type::Function
            return false unless @actual in Type::Function

            @actual.args.size == @expected.args.size + 1
          end

          def infix_error(operator)
            if @expected.args.first != @actual.args.first
              return "Left side of (#{operator}) expects #{naming[@expected.args.first]} " \
                "but found #{naming[@actual.args.first]}"
            end

            if @expected.args.last != @actual.args.last
              return "Right side of (#{operator}) expects #{naming[@expected.args.last]} " \
                "but found #{naming[@actual.args.last]}"
            end

            "Function call mismatch, expected #{naming[@expected]} but found #{naming[@actual]}"
          end
        end
      end
    end
  end
end

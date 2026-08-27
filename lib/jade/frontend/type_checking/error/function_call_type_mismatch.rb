module Jade
  module Frontend
    module TypeChecking
      module Error
        class FunctionCallTypeMismatch < TypeMismatch
          def initialize(
            entry, span, expected:, actual:, infix:, lifted_placeholder:,
            callee_name:, arg_names:
          )
            super
            @infix = infix
            @lifted_placeholder = lifted_placeholder
            @callee_name = callee_name
            @arg_names = arg_names
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
            return placeholder_note if one_too_many_for_the_placeholder?
            return arity_note if wrong_arity?
            return under_applied_note if under_applied

            []
          end

          private

          def placeholder_note
            ('a `_` makes this a function waiting for that argument, and the ' \
              'call has one argument too many for that. If you piped into it, ' \
              '`|>` already supplies the first argument, so drop the `_`')
              .then { help(it) }
          end

          def arity_note
            "#{subject(@callee_name, 'this')} takes #{count(@expected.args.size)}, " \
              "#{@actual.args.size} given"
              .then { help(it) }
          end

          # An argument that arrives as a function returning what was wanted
          # is a constructor or function that has not been given everything
          # it needs.
          def under_applied_note
            @actual
              .args[under_applied]
              .args
              .size
              .then { count(it) }
              .then { "#{under_applied_subject} needs #{it}" }
              .then { help(it) }
          end

          def under_applied_subject
            subject(@arg_names[under_applied], "argument #{under_applied + 1}")
          end

          def under_applied
            return nil unless comparable_calls?
            return nil unless @expected.args.size == @actual.args.size

            @expected.args.zip(@actual.args).index do |want, got|
              got.is_a?(Type::Function) &&
                !want.is_a?(Type::Function) &&
                got.return_type == want
            end
          end

          def wrong_arity?
            comparable_calls? && @expected.args.size != @actual.args.size
          end

          def comparable_calls?
            !@infix && (@expected in Type::Function) && (@actual in Type::Function)
          end

          def subject(name, fallback)
            name ? "`#{name}`" : fallback
          end

          def count(n)
            "#{n} #{n == 1 ? 'argument' : 'arguments'}"
          end

          def help(text)
            [Jade::Diagnostics::Annotation[:help, text]]
          end

          # `xs |> f(_, y)` reads as though the `_` marks where the piped
          # value goes, but `|>` has already put it in front of it.
          def one_too_many_for_the_placeholder?
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

module Jade
  module Frontend
    module TypeChecking
      module Error
        class FunctionCallTypeMismatch < TypeMismatch
          def initialize(entry, span, expected:, actual:, infix:)
            super
            @infix = infix
          end

          def message
            case @infix 
            in AST::InfixOperator(value:)
              infix_error(value)
            else
              "Function call mismatch, expected #{@expected} but found #{@actual}"
            end
          end

          private

          def infix_error(operator)
            if @expected.args.first != @actual.args.first
              return "Left side of (#{operator}) expects #{@expected.args.first} but found #{@actual.args.first}"
            end

            if @expected.args.last != @actual.args.last
              return "Right side of (#{operator}) expects #{@expected.args.last} but found #{@actual.args.last}"
            end

            "Function call mismatch, expected #{@expected} but found #{@actual}"
          end
        end
      end
    end
  end
end

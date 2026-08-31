module Jade
  module Frontend
    module TypeChecking
      module Inference
        # `/` asks for a `NonZero`, which nothing but `non_zero` can build.
        # A literal is the exception: the compiler can see whether it is
        # zero, so `cents / 100` needs no ceremony and `n / 0` is caught
        # where it is written.
        module Division
          extend self

          OPERATOR = '(/)'.freeze

          # Lifted even when the literal is zero: the divide-by-zero error is
          # the one worth reading, and a type mismatch under it is noise.
          def lift(node, acc)
            return acc unless divisor(node)

            acc.with(types: [*acc.types[0..-2], non_zero(acc.types.last)])
          end

          def by_zero(node, entry_name)
            return [] unless divisor(node)&.zero?

            [Error::DivisionByZero.new(entry_name, node.args.last.range)]
          end

          private

          def divisor(node)
            return nil unless node.args.size == 2 && operator?(node.callee)

            case node.args.last
            in AST::Literal(value: ::Integer | ::Float => value) then value
            else nil
            end
          end

          def operator?(callee)
            callee in AST::VariableReference(name: OPERATOR)
          end

          def non_zero(type)
            Type.constructor('Basics.NonZero').apply([type])
          end
        end
      end
    end
  end
end

module Jade
  module AST
    module PrettyPrinter
      extend self

      def print(node, indent = 0)
        prefix = '  ' * indent

        case node
        in AST::VariableReference(name:)
          prefix + "Var(#{name})"

        in AST::VariableBinding(name:, expression:)
          prefix + "VarBound(#{name} = " + print(expression, indent) + ")"

        in AST::Literal(value:)
          case value
          in Integer | TrueClass | FalseClass
            value.to_s

          in String
            "\"#{value}\""
          end
        in AST::FunctionCall(callee:, args:)
          case callee
          in AST::VariableReference(name:)
            if is_infix?(name)
              operator = name.delete_prefix('(').delete_suffix(')')

              return prefix + "(#{print(args[0])} #{operator} #{print(args[1])})"
            end
          else
          end

          args
            .map { print(it) }.join(', ')
            .then { "(#{it})"}
            .then { prefix + print(callee, indent) + it }
        end
      end

      private

      def is_infix?(name)
        name.start_with?('(') &&
          name.end_with?(')')
      end
    end
  end
end

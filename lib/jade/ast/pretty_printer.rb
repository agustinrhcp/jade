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
        end
      end
    end
  end
end

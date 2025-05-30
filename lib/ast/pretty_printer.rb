require 'ast'

module AST
  module PrettyPrinter
    extend self

    def print(node, indent=0)
      prefix = '  ' * indent
      case node
      in Binary(left:, operator:, right:)
        "#{prefix}Binary(\n" \
        "#{print(left, indent + 1)},\n" \
        "#{prefix}  operator: #{operator.inspect},\n" \
        "#{print(right, indent + 1)}\n" \
        "#{prefix})"
      in Literal(value:)
        "#{prefix}Literal(value: #{value.inspect})"
      in Variable(name:)
        "#{prefix}Variable(name: #{name})"
      in Unary(operator:, right:)
        "#{prefix}Unary(\n" \
        "#{prefix}  operator: #{operator.inspect},\n" \
        "#{print(right, indent + 1)}\n" \
        "#{prefix})"
      in Grouping(expression:)
        "#{prefix}Grouping(\n" \
        "#{print(expression, indent + 1)}\n" \
        "#{prefix})"
      in VariableDeclaration(name:, expression:)
        "#{prefix}Variable Declaration(\n" \
        "#{prefix}  name: #{name},\n" \
        "#{print(expression, indent + 1)}\n" \
        "#{prefix})"
      end
    end
  end
end

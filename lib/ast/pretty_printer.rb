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
      in Grouping(expression:)
        "#{prefix}Grouping(\n" \
        "#{print(expression, indent + 1)}\n" \
        "#{prefix})"
      end
    end
  end
end

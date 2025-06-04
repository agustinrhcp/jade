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

      in Program(statements:)
        "#{prefix}Program(\n" \
        "#{statements.map { |stmt| print(stmt, indent + 1) }.join(",\n")}\n" \
        "#{prefix})"

      in Parameter(name:, type:)
        "#{prefix}Parameter(\n" \
        "#{prefix}  name: #{name}\n" \
        "#{prefix}  type: #{type}\n" \
        "#{prefix})"

      in ParameterList(parameters:)
        "#{prefix}ParameterList(\n" \
        "#{parameters.map { |param| print(param, indent + 1) }.join(",\n")}\n" \
        "#{prefix})"

      in FunctionDeclaration(name:, parameters:, return_type:, body:)
        "#{prefix}Function Declaration(\n" \
        "#{prefix}  name: #{name},\n" \
        "#{prefix}  parameters: #{print(parameters)}" \
        "#{prefix}  returning type: #{return_type}" \
        "#{body.map { |stmt| print(stmt, indent + 1) }.join(",\n")}\n" \
        "#{prefix})"

      in FunctionCall(name:, arguments:)
        args_str = if arguments.empty?
            "#{prefix}    (no arguments)"
          else
            arguments.map { |arg| print(arg, indent + 2) }.join(",\n")
          end

        "#{prefix}Function Call(\n" \
        "#{prefix}  name: #{name},\n" \
        "#{prefix}  arguments: \n" \
        "#{args_str}\n" \
        "#{prefix})"
      end
    end
  end
end

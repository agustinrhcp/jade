require 'ast'

module Generator
  extend self

  def generate(node)
    case node
    in AST::Literal(value:)
      value.inspect
    in AST::Variable(name:)
      name.to_s
    in AST::Unary(operator:, right:)
      "#{operator}#{generate(right)}"
    in AST::Binary(left:, operator:, right:)
      "#{generate(left)} #{operator} #{generate(right)}"
    in AST::Grourping(expression:)
      "(#{generate(expression)})"
    in AST::VariableDeclaration(name:, expression:)
      "#{name} = #{generate(expression)}"
    in AST::Program(statements:)
      statements.map { generate(it) }.join("\n")
    end
  end
end

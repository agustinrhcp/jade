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
    in AST::Grouping(expression:)
      "(#{generate(expression)})"
    in AST::VariableDeclaration(name:, expression:)
      "#{name} = #{generate(expression)}"
    in AST::Program(statements:)
      statements.map { generate(it) }.join("\n")
    in AST::FunctionDeclaration(name:, parameters:, body:)
      "def #{name}(#{parameters.parameters.map(&:name).join(', ')})\n" +
        "  " + body.map { generate(it) }.join("\n") + "\n" +
        "end"
    in AST::FunctionCall(name:, arguments:)
      "#{name}(#{arguments.map { generate(it) }.join(', ')})"
    in AST::RecordDeclaration(name:, fields:)
      "#{name} = Data.define(#{fields.map { |f| ":#{f.name}"}.join(', ')})"
    end
  end
end

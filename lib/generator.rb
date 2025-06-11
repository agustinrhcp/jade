require 'ast'

module Generator
  extend self

  INDENT = '  '.freeze

  def generate(node, indents = 0)
    prefix = INDENT * indents

    case node
    in AST::Literal(value:)
      prefix + value.inspect
    in AST::Variable(name:)
      prefix + name.to_s
    in AST::Unary(operator:, right:)
      prefix + "#{operator}#{generate(right)}"
    in AST::Binary(left:, operator:, right:)
      prefix + "#{generate(left)} #{operator} #{generate(right)}"
    in AST::Grouping(expression:)
      prefix + "(#{generate(expression)})"
    in AST::VariableDeclaration(name:, expression:)
      prefix + "#{name} = #{generate(expression)}"
    in AST::Program(statements:)
      statements.map { generate(it, indents) }.join("\n")

    in AST::FunctionDeclaration(name:, parameters:, body:)
      "#{prefix}def #{name}(#{parameters.parameters.map(&:name).join(', ')})\n" +
        body.map { generate(it, indents + 1) }.join("\n") + "\n" +
        "#{prefix}end"

    in AST::FunctionCall(name:, arguments:)
      "#{prefix}#{name}(#{arguments.map { generate(it) }.join(', ')})"

    in AST::RecordDeclaration(name:, fields:)
      "#{prefix}#{name} = Data.define(#{fields.map { |f| ":#{f.name}"}.join(', ')})"

    in AST::Module(name:, exposing:, statements:)
      mod_names = name.split('.')
      generated_header = mod_names
        .each_with_index.map { |mod, i| "#{INDENT * i}module #{mod}"}
        .join("\n")

      generated_footer = mod_names
        .each_with_index.map { |mod, i| "#{INDENT * (mod_names.size - i - 1)}end"}
        .join("\n")

      geneated_statements = statements
        .map { generate(it, indents + mod_names.size) }

      [generated_header, geneated_statements, generated_footer].join("\n") + "\n"
    end
  end
end

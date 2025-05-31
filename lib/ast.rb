require 'position'

module AST
  extend self

  Binary = Data.define(:left, :operator, :right) do
    def range
      Range.new(left.range.start, right.range.end)
    end
  end

  Unary    = Data.define(:operator, :right, :range)
  Literal  = Data.define(:value, :type, :range)
  Variable = Data.define(:name, :type, :range)
  Grouping = Data.define(:expression, :range)

  VariableDeclaration = Data.define(:name, :expression, :range)

  Program = Data.define(:statements)

  Range = Data.define(:start, :end)

  def grouping
    ->(stuff) do
      stuff => [lparen, expression, rparen]
      Grouping.new(expression:, range: Range.new(lparen.position, rparen.position))
    end
  end

  def binary
    ->(left, operator, right) do
      Binary.new(left:, operator: operator.value.to_sym, right:)
    end
  end

  def unary
    ->(stuff) do
      stuff => [operator, right]
      Unary.new(
        operator: operator.value.to_sym,
        right:,
        range: Range.new(operator.position, right.range.end),
      )
    end
  end

  def literal
    ->(token) do
      Literal.new(
        value: token.value,
        type: token.type,
        # TODO: .to_s is hacky but let's leave it for now
        range: Range.new(token.position, token.position.offset_by_string(token.value.to_s))
      )
    end
  end

  def variable
    ->(token) do
      AST::Variable.new(
        name: token.value,
        range: Range.new(token.position, token.position.offset_by_string(token.value)),
        type: nil
      )
    end
  end

  def variable_declaration
    ->(stuff) do
      stuff => [_let, identifier, _assign, expression]
      AST::VariableDeclaration.new(
        name: identifier.value,
        expression:,
        range: Range.new(_let.position, expression.range.end)
      )
    end
  end

  def program
    ->(statements) do
      AST::Program.new(statements:)
    end
  end
end

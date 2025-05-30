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
end

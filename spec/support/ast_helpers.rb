module AstHelpers
  def lit(value)
    AST::Literal.new(value:, type: nil, range: dummy_range)
  end

  def bin(left, operator, right)
    AST::Binary.new(left:, operator:, right:)
  end

  def grp(expression)
    AST::Grouping.new(expression:, range: dummy_range)
  end

  private

  def dummy_range
    AST::Range.new(Position.new, Position.new)
  end
end

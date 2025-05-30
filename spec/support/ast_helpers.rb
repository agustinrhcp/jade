module AstHelpers
  def lit(value)
    type = case value
      in String then :string
      in Integer then :int
      in true | false then :bool
      end
    AST::Literal.new(value:, type:, range: dummy_range)
  end

  def bin(left, operator, right)
    AST::Binary.new(left:, operator:, right:)
  end

  def grp(expression)
    AST::Grouping.new(expression:, range: dummy_range)
  end

  def var(name, type: nil)
    AST::Variable.new(name:, type:, range: dummy_range)
  end

  def uny(operator, right)
    AST::Unary.new(operator:, right:, range: dummy_range)
  end

  def var_dec(name, expression)
    AST::VariableDeclaration.new(name:, expression:, range: dummy_range)
  end

  private

  def dummy_range
    AST::Range.new(Position.new, Position.new)
  end
end

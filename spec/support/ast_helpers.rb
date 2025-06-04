require 'type'

module AstHelpers
  def lit(value)
    type = case value
      in String then Type.string
      in Integer then Type.int
      in true | false then Type.bool
      end

    AST::Literal.new(value:, type:, range: dummy_range)
  end

  def bin(left, operator, right)
    AST::Binary.new(left:, operator:, right:)
  end

  def grp(expression)
    AST::Grouping.new(expression:, range: dummy_range)
  end

  def var(name)
    AST::Variable.new(name:, range: dummy_range)
  end

  def uny(operator, right)
    AST::Unary.new(operator:, right:, range: dummy_range)
  end

  def var_dec(name, expression)
    AST::VariableDeclaration.new(name:, expression:, range: dummy_range)
  end

  def param(name, type)
    AST::Parameter.new(name:, type:, range: dummy_range)
  end

  def params(*parameters)
    AST::ParameterList.new(parameters:)
  end

  def fn_dec(name, parameters, return_type, *body)
    AST::FunctionDeclaration.new(
      name:, parameters:, return_type:, body:, range: dummy_range,
    )
  end

  def fn_call(name, *arguments)
    AST::FunctionCall.new(
      name:, arguments:, range: dummy_range,
    )
  end

  def prog(*statements)
    AST::Program.new(statements:)
  end

  private

  def dummy_range
    AST::Range.new(Position.new, Position.new)
  end
end

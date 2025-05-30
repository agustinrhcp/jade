require 'ast'

module TypeChecker
  extend self

  UNARY_OP_RULES = {
    :! => { [:bool] => :bool },
    :- => { [:int] => :int},
  }

  BINARY_OP_RULES = {
    :+  => { [:int, :int] => :int },
    :-  => { [:int, :int] => :int },
    :*  => { [:int, :int] => :int },
    :/  => { [:int, :int] => :int },
    :== => {
      [:bool, :bool] => :bool,
      [:int, :int] => :bool,
      [:string, :string] => :bool,
    },
    :!= => {
      [:bool, :bool] => :bool,
      [:int, :int] => :bool,
      [:string, :string] => :bool,
    },
    :<  => { [:int, :int] => :bool },
    :<= => { [:int, :int] => :bool },
    :>  => { [:int, :int] => :bool },
    :>= => { [:int, :int] => :bool },
  }

  def check(node)
    case node
    in AST::Literal(type:)
      type

    in AST::Grouping(expression:)
      check(expression)

    in AST::Unary(operator:, right:)
      operand_type = check(node.right)
      UNARY_OP_RULES.dig(operator, [operand_type]) or
        raise Error, "Unary '#{node.operator}' not valid for #{operand_type}"

    in AST::Binary(left:, operator:, right:)
      left_operand_type = check(node.left)
      right_operand_type = check(node.right)
      BINARY_OP_RULES.dig(operator, [left_operand_type, right_operand_type]) or
        raise Error, "Binary '#{operator}' not valid for (#{left_operand_type}, #{right_operand_type})"

    end
  end

  class Error < StandardError; end
end

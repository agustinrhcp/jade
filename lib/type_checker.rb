require 'ast'
require 'result'

require 'refinements/or_else'

module TypeChecker
  extend self

  using Refinements::OrElse

  UNARY_OP_RULES = {
    :! => { :bool => :bool },
    :- => { :int => :int},
  }

  BINARY_OP_RULES = {
    :+  => { :int => { :int => :int } },
    :-  => { :int => { :int => :int } },
    :*  => { :int => { :int => :int } },
    :/  => { :int => { :int => :int } },
    :== => {
      :bool => { :bool => :bool },
      :int => { :int => :bool },
      :string => { :string => :bool },
    },
    :!= => {
      :bool => { :bool => :bool },
      :int => { :int => :bool },
      :string => { :string => :bool },
    },
    :<  => { :int => { :int => :bool } },
    :<= => { :int => { :int => :bool } },
    :>  => { :int => { :int => :bool } },
    :>= => { :int => { :int => :bool } },
  }

  def check(node)
    case node
    in AST::Literal(type:)
      Ok[type]

    in AST::Grouping(expression:)
      check(expression)

    in AST::Unary(operator:, right:)
      check(node.right)
        .and_then do |operand_type|
          UNARY_OP_RULES.dig(operator, operand_type)
            .then { return Ok[it] if it }

          Err[Error.new("Unary '#{node.operator}' not valid for #{operand_type}", range: node.range)]
        end

    in AST::Binary(left:, operator:, right:)
      check(node.left)
        .and_then do |left_operand_type|
          check(node.right)
            .and_then do |right_operand_type|
              BINARY_OP_RULES.dig(operator, left_operand_type)
                .or_else { return left_type_error(node, BINARY_OP_RULES[operator].keys) }
                .dig(right_operand_type)
                .or_else { return right_type_error(node, left_operand_type) }
                .then { Ok[it] }
            end
        end
    end
  end

  private

  def left_type_error(node, expected_types)
    message = case expected_types
      in [expected_type]
        "Left operand of '#{node.operator}' must be #{expected_type}, got #{node.left.type}"
      else
        "Left operand of '#{node.operator}' must be one of #{expected_types.map(&:to_s).sort.join(', ')}, got #{node.left.type}"
      end

    Err[Error.new(message, range: node.left.range)]
  end

  def right_type_error(node, expected_type)
    Err[
      Error.new(
        "Right operand of '#{node.operator}' must be #{expected_type}, got #{node.right.type}",
        range: node.right.range,
      )
    ]
  end

  class Error < StandardError
    attr_reader :range

    def initialize(message, range:)
      @range = range
      super(message)
    end
  end
end

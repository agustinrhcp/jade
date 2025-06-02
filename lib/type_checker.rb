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

  def check(node, scope = Scope.new)
    case node
    in AST::Literal(type:)
      Ok[[type, scope]]

    in AST::Grouping(expression:)
      check(expression, scope)

    in AST::Unary(operator:, right:)
      check(node.right, scope)
        .and_then do |(operand_type, new_scope)|
          UNARY_OP_RULES.dig(operator, operand_type)
            .then { return Ok[[it, new_scope]] if it }

          Err[Error.new("Unary '#{node.operator}' not valid for #{operand_type}", range: node.range)]
        end

    in AST::Binary(left:, operator:, right:)
      check(node.left, scope)
        .and_then do |(left_operand_type, scope_after_left)|
          check(node.right, scope_after_left)
            .and_then do |(right_operand_type, scope_after_right)|
              BINARY_OP_RULES.dig(operator, left_operand_type)
                .or_else { return left_type_error(node, BINARY_OP_RULES[operator].keys) }
                .dig(right_operand_type)
                .or_else { return right_type_error(node, actual: right_operand_type, expected: left_operand_type) }
                .then { Ok[[it, scope_after_right]] }
            end
        end

    in AST::VariableDeclaration(name:, expression:, range:)
      check(expression, scope)
        .map { |(type, new_scope)| [type, new_scope.define(TypedVar.new(name, type, range))] }

    in AST::Variable(name:)
      if scope.resolve(name)
        # What if it is untyped?
        Ok[[scope.resolve(name).type, scope]]
      else
        # Should never reach here, this should be caught by
        #  the semantic analyzer.
        Err[Error.new("Undefined variable '#{name}'", range: node.range)]
      end

    in AST::Program(statements:)
      statements.reduce(Ok[[nil, scope]]) do |acc, stmt|
        acc => Ok([_, new_scope])
        check(stmt, new_scope)
          .on_err { return Err[it] }
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

  def right_type_error(node, actual:, expected:)
    Err[
      Error.new(
        "Right operand of '#{node.operator}' must be #{expected}, got #{actual}",
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

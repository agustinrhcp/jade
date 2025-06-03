require 'ast'
require 'result'
require 'type'

require 'refinements/or_else'

module TypeChecker
  extend self

  using Refinements::OrElse

  UNARY_OP_RULES = {
    :! => { BOOL => BOOL },
    :- => { INT => INT},
  }

  BINARY_OP_RULES = {
    :+  => { INT => { INT => INT } },
    :-  => { INT => { INT => INT } },
    :*  => { INT => { INT => INT } },
    :/  => { INT => { INT => INT } },
    :== => {
      BOOL => { BOOL => BOOL },
      INT => { INT => BOOL },
      STRING => { STRING => BOOL },
    },
    :!= => {
      BOOL => { BOOL => BOOL },
      INT => { INT => BOOL },
      STRING => { STRING => BOOL },
    },
    :<  => { INT => { INT => BOOL } },
    :<= => { INT => { INT => BOOL } },
    :>  => { INT => { INT => BOOL } },
    :>= => { INT => { INT => BOOL } },
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
        .map { |(type, new_scope)| [type, new_scope.define_typed_var(name, type, range)] }

    in AST::Variable(name:)
      if scope.resolve(name)
        # What if it is untyped?
        Ok[[scope.resolve(name).type, scope]]
      else
        # Should never reach here, this should be caught by
        #  the semantic analyzer.
        Err[Error.new("Undefined variable '#{name}'", range: node.range)]
      end
    in AST::FunctionDeclaration(name:, parameters:, return_type:, body:, range:)
      if scope.resolve(name)
        Err[Error.new("Function '#{name}' is already defined", range: node.range)]
      else
        fn_type = Type::Function.new(parameters.parameters.map(&:type), return_type)

        new_scope = scope.define_typed_function(name, fn_type, range)
        fn_scope = parameters.parameters.reduce(new_scope) do |acc, param|
          acc.define_typed_var(param.name, param.type, param.range)
        end

        check_many(fn_scope, body)
          .and_then do |(typed_body, _)|
            if typed_body != return_type
              return Err[Error.new("Expected return type #{return_type}, got #{typed_body.type}", range: typed_body.range)]
            end

            Ok[[fn_type, new_scope]]
          end
      end

    in AST::Program(statements:)
      check_many(scope, statements)
    end
  end

  private

  def check_many(scope, nodes)
    nodes.reduce(Ok[[nil, scope]]) do |acc, node|
      acc => Ok([_, new_scope])
      check(node, new_scope)
    end
  end

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

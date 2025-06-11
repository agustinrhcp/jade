require 'ast'
require 'result'
require 'type'

require 'refinements/or_else'

module TypeChecker
  extend self

  using Refinements::OrElse

  UNARY_OP_RULES = {
    :! => { Type.bool => Type.bool },
    :- => { Type.int => Type.int},
  }.freeze

  BINARY_OP_RULES = {
    :+  => { Type.int => { Type.int => Type.int } },
    :-  => { Type.int => { Type.int => Type.int } },
    :*  => { Type.int => { Type.int => Type.int } },
    :/  => { Type.int => { Type.int => Type.int } },
    :== => {
      Type.bool => { Type.bool => Type.bool },
      Type.int => { Type.int => Type.bool },
      Type.string => { Type.string => Type.bool },
    },
    :!= => {
      Type.bool => { Type.bool => Type.bool },
      Type.int => { Type.int => Type.bool },
      Type.string => { Type.string => Type.bool },
    },
    :<  => { Type.int => { Type.int => Type.bool } },
    :<= => { Type.int => { Type.int => Type.bool } },
    :>  => { Type.int => { Type.int => Type.bool } },
    :>= => { Type.int => { Type.int => Type.bool } },
  }.freeze

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
                .or_else { return left_type_error(node, expected: BINARY_OP_RULES[operator].keys, actual: left_operand_type) }
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
      case scope.resolve(name)
      in TypedFunction
        Err[Error.new("Function '#{name}' is already defined", range: node.range)]
      in UnboundFunction | nil
        fn_type = Type::Function.new(parameters.parameters.map(&:type), return_type)

        new_scope = scope.define_typed_function(name, fn_type, range)
        fn_scope = parameters.parameters.reduce(new_scope) do |acc, param|
          acc.define_typed_var(param.name, param.type, param.range)
        end

        check_many(fn_scope, body)
          .and_then do |(typed_body, _)|
            if typed_body.last != return_type
              return Err[Error.new("Expected return type #{return_type}, got #{typed_body.last}", range: body.last.range)]
            end

            Ok[[fn_type, new_scope]]
          end
      end

    in AST::FunctionCall(name:, arguments:)
      fn = scope.resolve(name)

      check_many(scope, arguments)
        .and_then do |(argument_types, _)|
          fn
            .type
            .parameters
            .zip(argument_types)
            .each.with_index
            .reduce(Ok[[fn.type.return_type, scope]]) do |acc, ((param_type, argument_type), i)|
              next acc if param_type == argument_type

              return Err[
                Error.new("Expected argument #{i} of type #{param_type}, got #{argument_type}", range: nil),
              ]
            end
        end

    in AST::RecordDeclaration(name:, fields:)
      record_type = Type::Record.new(name, Hash[fields.map { |f| [f.name, f.type] }])
      Ok[[record_type, scope.define_typed_record(name, fields, record_type)]]

    in AST::AnonymousRecord(fields:)
      fields
        .reduce(Ok[{}]) do |acc, field|
          case [acc, check(field, scope)]
          in [Ok(acc_types), Ok([field_type, _])]
            Ok[acc_types.merge(field.name => field_type)]
          in [Ok, Err(errors)]
            Err[errors]
          in Err(acc_error), Err(field_errors)
            acc
            # TODO: Return multiple errors
            # Err[acc_errors.concat(field_errors)]
          in Err, Ok
            acc
          end
        end
          .map { |typed_fields| [Type::Record.new(nil, typed_fields), scope] }

    in AST::RecordInstantiation(name:, fields:)
      type = scope.resolve_record(name)&.type

      unless type
        # This should be caught by semantic analysis
        return Err[[
          Error.new("Undefined record type '#{name}'", range: node.range)
        ]]
      end

      fields
        .reduce(Ok[nil]) do |acc, field|
          checked_and_compared_result =
            check(field)
              .and_then do |(checked, _)|
                next Ok[nil] if checked == type.fields[field.name]

                Err[Error.new("Field '#{field.name}' expects #{type.fields[field.name]}, got #{checked}", range: field.range)]
              end

          case [acc, checked_and_compared_result]
          in Ok, Ok
            acc
          in Err(errors), Err(new_error)
            Err[errors.concat([new_error])]
          in Ok, Err(error)
            Err[[error]]
          else
            acc
          end
        end
        .map { [type, scope] }

    in AST::RecordFieldAssign(expression:)
      check(expression, scope)

    in AST::Program(statements:)
      check_many(scope, statements)

    in AST::Module(statements:)
      check_many(scope, statements)
    end
  end

  private

  def check_many(scope, nodes)
    nodes.reduce(Ok[[[], scope]]) do |acc, node|
      acc => Ok([all_checked, new_scope])
      check(node, new_scope)
        .map do |(checked, new_scope)|
          [all_checked.concat([checked]), new_scope]
        end
    end
  end

  def left_type_error(node, expected:, actual:)
    message = case expected
      in [expected]
        "Left operand of '#{node.operator}' must be #{expected}, got #{actual}"
      else
        "Left operand of '#{node.operator}' must be one of #{expected.map(&:to_s).sort.join(', ')}, got #{actual}"
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

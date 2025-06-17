require 'ast'
require 'result'
require 'type'
require 'context'

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
    :'++' => { Type.string => { Type.string => Type.string } },
  }.freeze

  def check(node, context = Context.new)
    case node
    in AST::Literal(type:)
      Ok[[type, context]]

    in AST::Grouping(expression:)
      check(expression, context)

    in AST::Unary(operator:, right:)
      check(node.right, context)
        .and_then do |(operand_type, new_context)|
          UNARY_OP_RULES.dig(operator, operand_type)
            .then { return Ok[[it, new_context]] if it }

          Err[Error.new("Unary '#{node.operator}' not valid for #{operand_type}", range: node.range)]
        end

    in AST::Binary(left:, operator:, right:)
      check(node.left, context)
        .and_then do |(left_operand_type, context_after_left)|
          check(node.right, context_after_left)
            .and_then do |(right_operand_type, context_after_right)|
              BINARY_OP_RULES.dig(operator, left_operand_type)
                .or_else { return left_type_error(node, expected: BINARY_OP_RULES[operator].keys, actual: left_operand_type) }
                .dig(right_operand_type)
                .or_else { return right_type_error(node, actual: right_operand_type, expected: left_operand_type) }
                .then { Ok[[it, context_after_right]] }
            end
        end

    in AST::VariableDeclaration(name:, expression:, range:)
      check(expression, context)
        .map do |(type, new_context)|
          [type, new_context.define_var(name, expression).annotate_var(name, type)]
        end

    in AST::Variable(name:)
      if context.resolve_var(name)
        # What if it is untyped?
        Ok[[context.resolve_var(name).type, context]]
      else
        # Should never reach here, this should be caught by
        #  the semantic analyzer.
        Err[Error.new("Undefined variable '#{name}'", range: node.range)]
      end
    in AST::FunctionDeclaration(name:, parameters:, return_type:, body:, range:)
      annotated_parameters = parameters
        .parameters.map { |param| param.annotate(context.resolve_type(param.type)) }
      resolved_return_type = context.resolve_type(return_type)

      if resolved_return_type.nil?
        return Err[Error.new("Undefined type #{return_type}", range:)]
      end

      fn_type = Type::Function.new(annotated_parameters.map(&:type), resolved_return_type)
      new_context = context.annotate_fn(name, fn_type)

      fn_context = annotated_parameters
        .reduce(new_context) do |acc, param|
          acc
            .define_var(param.name, param)
            .annotate_var(param.name, param.type)
        end

      check_many(fn_context, body)
        .and_then do |(typed_body, _)|
          if typed_body.last != resolved_return_type
            return Err[Error.new("Expected return type #{resolved_return_type}, got #{typed_body.last}", range: body.last.range)]
          end

          Ok[[fn_type, new_context]]
        end

    in AST::FunctionCall(name:, arguments:)
      fn = context.resolve_fn(name)

      check_many(context, arguments)
        .and_then do |(argument_types, _)|
          fn
            .type
            .parameters
            .zip(argument_types)
            .each.with_index
            .reduce(Ok[[fn.type.return_type, context]]) do |acc, ((param_type, argument_type), i)|
              next acc if param_type == argument_type

              return Err[
                Error.new("Expected argument #{i} of type #{param_type}, got #{argument_type}", range: nil),
              ]
            end
        end

    in AST::RecordDeclaration(name:, params:, fields:)
      fields
        .reduce(Ok[[]]) do |acc, field|
          case [acc, resolve_type_reference(field.type, context)]
          in Ok, Err(err)
            Err[[err]]
          in Ok(ok_acc), Ok(resolved_type)
            Ok[ok_acc.concat([field.annotate(resolved_type)])]
          in Err(err_acc), Err(err)
            Err[err_acc.concat([err])]
          in Err, _
            acc
          end
        end
        .map do |annotated_fields|
          record_type = Type::Record
            .new(name, Hash[annotated_fields.map { |f| [f.name, f.type] }], params)
          [record_type, context.define_type(name, record_type)]
        end

    in AST::AnonymousRecord(fields:)
      fields
        .reduce(Ok[{}]) do |acc, field|
          case [acc, check(field, context)]
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
          .map { |typed_fields| [Type::Record.new(nil, typed_fields, []), context] }

    in AST::RecordInstantiation(name:, fields:)
      type = context.resolve_type(name)

      unless type
        # This should be caught by semantic analysis
        return Err[[
          Error.new("Undefined record type '#{name}'", range: node.range)
        ]]
      end

      fields
        .reduce(Ok[nil]) do |acc, field|
          checked_and_compared_result =
            check(field, context)
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
        .map { [type, context] }

    in AST::RecordFieldAssign(expression:)
      check(expression, context)

    in AST::RecordAccess(target:, field:)
      check(target, context)
        .and_then do |target_type, new_context|
          case target_type
          in Type::Record(name:, fields:)
            if fields[field]
              Ok[[fields[field], new_context]]
            else
              Err[Error.new("Record #{name} does not have a #{field} field")]
            end
          else
             Err[Error.new("#{target_type} is not a record and cannot be access with '.'")]
          end
        end

    in AST::UnionType(name:, variants:)
      variants
        .reduce(Ok[[]]) do |acc, variant|
          case [acc, check_variant(variant, context, name)]
          in [Ok(acc_ok), Ok(variant_type)]
            Ok[acc_ok + [variant_type]]
          in [Ok, Err => err]
            err
          in [Err, Ok]
            acc
          in [Err(acc_err), Err(err)]
            # TODO: return many errors Err[acc_err + err]
            Err[err]
          end
        end
        .map do |typed_checked_variants|
          type = Type::Union.new(name:, variants: typed_checked_variants)
          [type, node.annotate(type)]
        end

    in AST::Program(statements:)
      check_many(context, statements)

    in AST::Module(statements:)
      check_many(context, statements)
    end
  end

  private

  def resolve_type_reference(ast_ref, context)
    case ast_ref
    in AST::TypeRef(name:, range:)
      context.resolve_type(name)&.then { Ok[it]} ||
        Error.new("Undefined type #{name}", range:)
    in AST::GenericRef(name:)
      Ok[Type::Generic.new(name)]
    end
  end

  def check_variant(variant, context, union_type_name)
    variant => AST::Variant(name:, fields:, params:)

    type = case [fields, params]
    in [[], []]
      Ok[Type::VariantNullary.new(name:, union_type_name:)]
    in [some_fields, []] if some_fields.any?
      some_fields
        .reduce(Ok[{}]) do |acc, (f_k, f_v)|
          case [acc, context.resolve_type(f_v)]
          in [Ok, nil]
            Err[[Error.new("Undefined type for field #{f_k} #{f_v}", range: variant.range)]]
          in [Ok(ok_acc), a_type]
            Ok[ok_acc.merge(f_k, a_type)]
          in [Err(err_acc), nil]
            Err[err_acc + [Error.new("Undefined type for field #{f_k} #{f_v}", range: variant.range)]]
          in [Err, _]
            acc
          end
        end
        .map { Type::VariantRecord.new(name:, fields: it, union_type_name:) }
    in [[], some_params] if some_params.any?
      some_params
        .reduce(Ok[[]]) do |acc, param|
          case [acc, context.resolve_type(param.value)]
          in [Ok, nil]
            Err[[Error.new("Undefined type for variant #{name} '#{param.value}'", range: variant.range)]]
          in [Ok(ok_acc), a_type]
            Ok[ok_acc.concat([a_type])]
          in [Err(err_acc), nil]
            Err[error_acc + [Error.new("Undefined type for variant #{name} '#{param.value}'", range: variant.range)]]
          in [Err, _]
            acc
          end
        end
        .map { Type::VariantTuple.new(name:, params: it, union_type_name:) }
    end
  end

  def check_many(context, nodes)
    nodes.reduce(Ok[[[], context]]) do |acc, node|
      acc => Ok([all_checked, new_context])
      check(node, new_context)
        .map do |(checked, new_context)|
          [all_checked.concat([checked]), new_context]
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

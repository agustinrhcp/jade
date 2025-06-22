require 'ast'
require 'result'
require 'type'
require 'context'
require 'tuple'

require 'type_checker/helpers'
require 'type_checker/substitution'

require 'type_checker/function'
require 'type_checker/record'

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
      Ok[Tuple[node, context]]

    in AST::Grouping(expression:)
      check(expression, context)

    in AST::Unary(operator:, right:)
      check(node.right, context)
        .and_then do |(typed_right, new_context)|
          UNARY_OP_RULES.dig(operator, typed_right.type)
            .then { return Ok[Tuple[node.with(right: typed_right).annotate(it), new_context]] if it }

          Err[[Error.new("Unary '#{node.operator}' not valid for #{typed_right.type}", range: node.range)]]
        end

    in AST::Binary(left:, operator:, right:)
      check(node.left, context)
        .and_then do |(typed_left, context_after_left)|
          check(node.right, context_after_left)
            .and_then do |(typed_right, context_after_right)|
              BINARY_OP_RULES.dig(operator, typed_left.type)
                .or_else { return left_type_error(node, expected: BINARY_OP_RULES[operator].keys, actual: typed_left.type) }
                .dig(typed_right.type)
                .or_else { return right_type_error(node, actual: typed_right.type, expected: typed_left.type) }
                .then { Ok[Tuple[node.with(left: typed_left, right: typed_right).annotate(it), context_after_right]] }
            end
        end

    in AST::VariableDeclaration(name:, expression:, range:)
      check(expression, context)
        .map do |(typed_expression, new_context)|
          Tuple[
            node.with(expression: typed_expression).annotate(typed_expression.type),
            new_context.define_var(name).annotate_var(name, typed_expression.type),
          ]
        end

    in AST::Variable(name:)
      if context.resolve_var(name)
        # What if it is untyped?
        node
          .annotate(context.resolve_var(name).type)
          .then { Ok[Tuple[it, context]]}
      else
        # Should never reach here, this should be caught by
        #  the semantic analyzer.
        Err[[Error.new("Undefined variable '#{name}'", range: node.range)]]
      end
    in AST::FunctionDeclaration(name:, parameters:, return_type:, body:, range:)
      Function.check_declaration(node, context)

    in AST::FunctionCall(name:, arguments:)
      fn = context.resolve_fn(name)

      Helpers
        .check_many(arguments, context)
        .and_then do |(checked_arguments, _)|
          fn
            .type
            .parameters
            .zip(checked_arguments)
            .each.with_index
            .reduce(Ok[Tuple[checked_arguments, context]]) do |acc, ((param_type, checked_argument), i)|
              next acc if param_type == checked_argument.type

              # TODO: Accumulate errors.
              #   and move to Function.check_call
              return Err[
                [Error.new("Expected argument #{i} of type #{param_type}, got #{checked_argument.type}", range: nil),]
              ]
            end
        end
        .map do |(checked_arguments, new_context)|
          Tuple[
            node.with(arguments: checked_arguments).annotate(fn.type.return_type),
            new_context
          ]
        end

    in AST::RecordDeclaration(name:, params:, fields:)
      Helpers
        .walk_with_context(fields, context) do |field, new_context|
          check(field, new_context)
        end
        .map do |(checked_fields, _)|
          record_type = Type::Record
            # TODO: Fix the need of the flatten
            .new(name, Hash[checked_fields.map { |f| [f.name, f.type] }], params.flatten)

          Tuple[
            node.with(fields: checked_fields)
              .annotate(record_type),
            context.define_type(name, record_type),
          ]
        end

    in AST::RecordField(type:)
      resolve_type_reference(type, context)
        .map do |resolved_type|
          [node.annotate(resolved_type), context]
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
          .map do |checked_fields|
            type = Type::Record.new(nil, checked_fields, [])
            Tuple[node.with(fields: checked_fields).annotate(type), context]
          end

    in AST::RecordInstantiation
      Record.check_instantiation(node, context)

    in AST::RecordFieldAssign(expression:)
      check(expression, context)

    in AST::RecordAccess(target:, field:)
      check(target, context)
        .and_then do |checked_target, new_context|
          case checked_target.type
          in Type::Record(name:, fields:)
            if checked_target.type.fields[field]
              Ok[Tuple[
                node
                  .with(target: checked_target)
                  .annotate(checked_target.type.fields[field]),
                new_context,
              ]]
            else
              Err[[Error.new("Record #{name} does not have a #{field} field")]]
            end
          else
             Err[[Error.new("#{target_type} is not a record and cannot be access with '.'", range: node.range)]]
          end
        end

    in AST::UnionType(name:, variants:)
      Result
        .walk(variants) { |variant| check_variant(variant, context, name) }
        .map do |checked_variants|
          type = Type::Union.new(name:, variants: checked_variants)
          Tuple[node.with(variants: checked_variants).annotate(type), context]
        end

    in AST::Program(statements:)
      check_many(context, statements)

    in AST::Module(statements:)
      check_many(context, statements)
        .map { |(checked_statements, _)| node.with(statements: checked_statements) }
        .map { Tuple[it, context] }
    end
  end

  private

  def resolve_type_reference(ast_ref, context)
    # This can be part of the main ast nodes case, but declaration and
    #  instantiation for generics differs.
    case ast_ref
    in AST::TypeRef(name:, range:)
      context.resolve_type(name)&.then { Ok[it]} ||
        Err[[UnresolvedTypeError.new(name, range:)]]
    in AST::GenericRef(name:)
      Ok[Type::Generic.new(name)]
    end
  end

  def check_variant(variant, context, union_type_name)
    variant => AST::Variant(name:, fields:, params:)

    type = case [fields, params]
    in [[], []]
      type = Type::VariantNullary.new(name:, union_type_name:)
      Ok[variant.annotate(type)]

    in [some_fields, []] if some_fields.any?
      some_fields
        .reduce(Ok[{}]) do |acc, (f_k, f_v)|
          case [acc, context.resolve_type(f_v)]
          in [Ok, nil]
            Err[[[
              Error.new("Undefined type for field #{f_k} #{f_v}", range: variant.range)
            ], context]]
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

    Ok[variant.annotate(type)]
  end

  def check_many(context, nodes)
    nodes.reduce(Ok[Tuple[[], context]]) do |acc, node|
      acc => Ok(Tuple[all_checked, new_context])

      check(node, new_context)
        .map do |(checked, new_context)|
          Tuple[all_checked.concat([checked]), new_context]
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

    Err[[Error.new(message, range: node.left.range)]]
  end

  def right_type_error(node, actual:, expected:)
    Err[[
      Error.new(
        "Right operand of '#{node.operator}' must be #{expected}, got #{actual}",
        range: node.right.range,
      )
    ]]
  end

  class Error < StandardError
    attr_reader :range

    def initialize(message, range:)
      @range = range
      super(message)
    end
  end

  class UnresolvedTypeError < Error
    def initialize(type, range:)
      super("Unresolved type #{type}", range:)
    end
  end
end

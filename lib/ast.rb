require 'position'

module AST
  extend self

  module Node
    def annotate(type: nil, context: nil)
      with(**{ type:, context: }.compact)
    end

    def annotate_context(context)
      with(context:)
    end
  end

  def define_ast_node(name, *fields)
    const_set(name, Data.define(*fields, :range, :type, :context) {
      include Node

      define_method(:initialize) do |**kwargs|
        kwargs[:type] ||= nil
        kwargs[:context] ||= nil
        super(**kwargs)
      end
    })
  end

  define_ast_node(:Binary, :left, :operator, :right)
  define_ast_node(:Unary, :operator, :right)
  define_ast_node(:Literal, :value)
  define_ast_node(:Grouping, :expression)

  define_ast_node(:Variable, :name)
  define_ast_node(:VariableDeclaration, :name, :expression)

  define_ast_node(:Parameter, :name)
  define_ast_node(:FunctionDeclaration, :name, :parameters, :return_type, :body)
  define_ast_node(:FunctionCall, :name, :arguments)
  define_ast_node(:RecordDeclaration, :name, :params, :fields)
  define_ast_node(:RecordField, :name)
  define_ast_node(:RecordInstantiation, :name, :fields, :params)
  define_ast_node(:AnonymousRecord, :fields)
  define_ast_node(:RecordAccess, :target, :field)
  define_ast_node(:RecordFieldAssign, :name, :expression)

  define_ast_node(:UnionType, :name, :params, :variants)
  define_ast_node(:Variant, :name, :fields, :params)

  define_ast_node(:Program, :statements)

  TypeRef = Data.define(:name, :range)
  GenericRef = Data.define(:name, :range)


  # params if for generics

  VariantField = Data.define(:name, :value, :type, :range)
  VariantParam = Data.define(:value, :type, :range)

  Module  = Data.define(:name, :exposing, :statements, :range)

  Range = Data.define(:start, :end)

  def grouping
    ->((lparen, expression, rparen)) do
      Grouping.new(expression:, range: Range.new(lparen.position, rparen.position))
    end
  end

  def binary
    ->(left, operator, right) do
      Binary.new(
        left:,
        operator: operator.value.to_sym,
        right:,
        range: Range.new(left.range.start, right.range.end),
      )
    end
  end

  def unary
    ->((operator, right)) do
      Unary.new(
        operator: operator.value.to_sym,
        right:,
        range: Range.new(operator.position, right.range.end),
      )
    end
  end

  def literal
    ->(token) do
      Literal.new(
        value: token.value,
        type: case token.type
          in :int then Type.int
          in :string then Type.string
          in :bool then Type.bool
          end,
        # TODO: .to_s is hacky but let's leave it for now
        range: Range.new(token.position, token.position.offset_by_string(token.value.to_s))
      )
    end
  end

  def variable
    ->(token) do
      AST::Variable.new(
        name: token.value,
        range: Range.new(token.position, token.position.offset_by_string(token.value)),
      )
    end
  end

  def variable_declaration
    ->((identifier, expression)) do
      AST::VariableDeclaration.new(
        name: identifier.value,
        expression:,
        range: Range.new(identifier.position, expression.range.end)
      )
    end
  end

  def parameter
    ->((name, type)) do
      AST::Parameter.new(
        name: name.value,
        type: type.value,
        range: Range.new(name.position, type.position),
      )
    end
  end

  def function_declaration
    ->(tokens) do
      tokens => [
        name,
        parameters,
        return_type,
        body,
      ]

      AST::FunctionDeclaration.new(
        name: name.value,
        parameters:,
        return_type: return_type.value,
        body:,
        range: Range.new(name.position, body.last.range.end),
      )
    end
  end

  def function_call
    ->((name, *arguments)) do
      AST::FunctionCall.new(
        name: name.value,
        arguments: arguments,
        range: Range.new(name.position, arguments&.last&.range&.end || name.position),
      )
    end
  end

  def record_declaration
    ->((name, params, *fields)) do
      AST::RecordDeclaration.new(
        name: name.value,
        fields:,
        params:,
        range: Range.new(name.position, fields.last&.range&.end || name.position),
      )
    end
  end

  def record_field
    ->((name, type)) do
      AST::RecordField.new(
        name: name.value,
        type: type,
        range: Range.new(name.position, type.range.end),
      )
    end
  end

  def type_ref
    ->(token) {
      AST::TypeRef.new(
        name: token.value,
        range: Range.new(token.position, token.position)
      )
    }
  end

  def generic_ref
    ->(token) {
      AST::GenericRef.new(
        name: token.value,
        range: Range.new(token.position, token.position)
      )
    }
  end

  def record_instantiation
    ->((name, *fields)) do
      AST::RecordInstantiation.new(
        name: name.value,
        fields:,
        params: [],
        range: Range.new(name.position, fields.last&.range&.end || name.position),
      )
    end
  end

  def anonymous_record
    ->((*fields)) do
      AST::AnonymousRecord.new(
        fields:,
        range: Range.new(fields.first.range.start, fields.last&.range&.end),
      )
    end
  end

  def record_field_assign
    ->((name, expression)) do
      AST::RecordFieldAssign.new(
        name: name.value,
        expression:,
        range: Range.new(name.position, expression.range.end),
      )
    end
  end

  def program
    ->(statements) do
      AST::Program
        .new(
          statements:,
          range: Range.new(statements.first.range.start, statements.last.range.end),
        )
    end
  end

  def module
    ->((name, exposing, *statements)) do
      AST::Module.new(
        name:,
        exposing:,
        statements:,
        range: Range.new(Position.new, statements.last.range),
      )
    end
  end
  def record_access
    ->(target, field) do
      AST::RecordAccess.new(
        target:,
        field: field.value,
        range: Range.new(target.range.start, field.position)
      )
    end
  end

  def union
    ->((name, params, *variants)) do
      AST::UnionType.new(
        name: name.value,
        params:,
        variants:,
        range: Range.new(name.position, variants.last.range.end),
      )
    end
  end

  def variant_field
    ->((name, value)) do
      AST::VariantField.new(
        name: name.value,
        value: value.value,
        type: nil,
        range: Range.new(name.position, value.position),
      )
    end
  end

  def variant_param
    ->((value)) do
      AST::VariantParam.new(
        value: value.value,
        type: nil,
        range: Range.new(value.position, value.position),
      )
    end
  end

  def variant
    -> ((name, fields_or_params)) do
      fields_or_params ||= {}
      AST::Variant.new(
        name: name.value,
        fields: fields_or_params[:fields] || [],
        params: fields_or_params[:params] || [],
        range: Range.new(name.position, name.position),
      )
    end
  end

  private

  def resolve_type(type_name)
    # TODO: Handle other types!
    case type_name
    in 'Int' then Type.int
    in 'String' then Type.string
    in 'Bool' then Type.bool
    else
      type_name
    end
  end
end

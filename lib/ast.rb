require 'position'

module AST
  extend self

  Binary = Data.define(:left, :operator, :right, :type) do
    def initialize(left:, operator:, right:, type: nil)
      super
    end

    def annotate(type)
      with(type:)
    end

    def range
      Range.new(left.range.start, right.range.end)
    end
  end

  Unary = Data.define(:operator, :right, :range, :type) do
    def initialize(operator:, right:, range:, type: nil)
      super
    end

    def annotate(type)
      with(type:)
    end
  end

  Literal = Data.define(:value, :type, :range)

  Grouping = Data.define(:expression, :range)

  Variable = Data.define(:name, :range, :type) do
    def initialize(name:, range:, type: nil)
      super
    end

    def annotate(type)
      with(type:)
    end
  end

  VariableDeclaration = Data.define(:name, :expression, :range, :type) do
    def initialize(name:, expression:, range:, type: nil)
      super
    end

    def annotate(type)
      with(type:)
    end
  end

  Parameter = Data.define(:name, :type, :range) do
    def annotate(type)
      with(type:)
    end
  end

  ParameterList = Data.define(:parameters) do
    def size
      parameters.size
    end
  end

  FunctionDeclaration = Data.define(:name, :parameters, :return_type, :type, :body, :range) do
    def initialize(name:, parameters:, return_type:, type: nil, body:, range:)
      super
    end

    def annotate(type)
      with(type:, return_type: type.return_type)
    end
  end

  FunctionCall = Data.define(:name, :arguments, :range, :type) do
    def initialize(name:, arguments:, range:, type: nil)
      super
    end

    def annotate(type)
      with(type:)
    end
  end

  RecordDeclaration   = Data.define(:name, :fields, :range)
  RecordField         = Data.define(:name, :type, :range) do
    def annotate(type)
      with(type:)
    end
  end
  RecordInstantiation = Data.define(:name, :fields, :range)

  RecordAccess = Data.define(:target, :field, :type, :range) do
    def initialize(target:, field:, type: nil, range:)
      super
    end

    def annotate(type)
      with(type:)
    end
  end

  AnonymousRecord     = Data.define(:fields, :range, :type) do
    def initialize(fields:, range:, type: nil)
      super
    end

    def annotate(type)
      with(type:)
    end
  end

  RecordFieldAssign   = Data.define(:name, :expression, :range)

  UnionType = Data.define(:name, :variants, :range)
  Variant = Data.define(:name, :fields, :range)

  Program = Data.define(:statements)
  Module  = Data.define(:name, :exposing, :statements, :range)

  Range = Data.define(:start, :end)

  def grouping
    ->((lparen, expression, rparen)) do
      Grouping.new(expression:, range: Range.new(lparen.position, rparen.position))
    end
  end

  def binary
    ->(left, operator, right) do
      Binary.new(left:, operator: operator.value.to_sym, right:)
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

  def parameter_list
    ->(parameters) do
      AST::ParameterList.new(parameters:)
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
    ->((name, *fields)) do
      AST::RecordDeclaration.new(
        name: name.value,
        fields:,
        range: Range.new(name.position, fields.last&.range&.end || name.position),
      )
    end
  end

  def record_field
    ->((name, type)) do
      AST::RecordField.new(
        name: name.value,
        type: type.value,
        range: Range.new(name.position, type.position),
      )
    end
  end

  def record_instantiation
    ->((name, *fields)) do
      AST::RecordInstantiation.new(
        name: name.value,
        fields:,
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
      AST::Program.new(statements:)
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
    ->((name, *variants)) do
      AST::UnionType.new(
        name: name.value,
        variants:,
        range: Range.new(name.position, variants.last.range.end),
      )
    end
  end

  def variant
    -> ((name, *fields)) do
      AST::Variant.new(
        name: name.value,
        fields: fields.compact,
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

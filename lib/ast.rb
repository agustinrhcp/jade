require 'position'

module AST
  extend self

  Binary = Data.define(:left, :operator, :right) do
    def range
      Range.new(left.range.start, right.range.end)
    end
  end

  Unary    = Data.define(:operator, :right, :range)
  Literal  = Data.define(:value, :type, :range)
  Grouping = Data.define(:expression, :range)

  Variable = Data.define(:name, :range)
  VariableDeclaration = Data.define(:name, :expression, :range)

  Parameter = Data.define(:name, :type, :range)
  ParameterList = Data.define(:parameters) do
    def size
      parameters.size
    end
  end

  FunctionDeclaration = Data.define(:name, :parameters, :return_type, :body, :range)
  FunctionCall        = Data.define(:name, :arguments, :range)

  RecordDeclaration = Data.define(:name, :fields, :range)
  RecordField       = Data.define(:name, :type, :range)

  Program = Data.define(:statements)

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
        type: resolve_type(type.value),
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
        return_type: resolve_type(return_type.value),
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

  def program
    ->(statements) do
      AST::Program.new(statements:)
    end
  end

  private

  def resolve_type(type_name)
    case type_name
    in 'Int' then Type.int
    in 'String' then Type.string
    in 'Bool' then Type.bool
    end
  end
end

module Jade
  module Codegen
    extend self

    def generate(node, registry)
      case node
      in AST::Body(expressions:)
        expressions
          .map { generate(it, registry) }.join("; ")

      in AST::VariableReference(name:)
        name

      in AST::VariableBinding(name:, expression:)
        "#{name} = #{generate(expression, registry)}"

      in AST::Literal(value:)
        case value
        in Integer | TrueClass | FalseClass
          value.to_s

        in String
          "\"#{value}\""
        end

      in AST::FunctionDeclaration(name:, params:, body:)
        params_code = params.map { generate(it, registry) }.join(', ')
        "def #{name}; ->(#{params_code}) { #{generate(body, registry)} }; end"

      in AST::FunctionDeclarationParam(name:)
        name
      end
    end

    private
  end
end

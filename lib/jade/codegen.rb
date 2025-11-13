module Jade
  module Codegen
    extend self

    def generate(node, registry)
      case node
      in AST::Literal(value:)
        case value
        in Integer | TrueClass | FalseClass
          value.to_s
        in String
          "\"#{value}\""
        end
      end
    end
  end
end

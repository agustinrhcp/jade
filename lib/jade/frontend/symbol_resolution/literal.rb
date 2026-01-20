module Jade
  module Frontend
    module SymbolResolution
      module Literal
        extend self

        def resolve(node, _, _)
          node => AST::Literal(value:)

          symbol_from_literal_value(value)
            .then { node.with(symbol: it) }
            .then { Result[it, []] }
        end

        private

        def symbol_from_literal_value(value)
          case value
          in Integer
            Symbol::TypeRef['Basics', 'Int']

          in TrueClass | FalseClass
            Symbol::TypeRef['Basics', 'Bool']

          in String
            Symbol::TypeRef['String', 'String']

          in Float
            Symbol::TypeRef['Basics', 'Float']
          end
        end
      end
    end
  end
end

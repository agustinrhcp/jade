module Jade
  module Frontend
    module SymbolResolution
      extend self

      def resolve(node, registry)
        case node
        in AST::Literal
          resolve_literal(node, registry) 
        end
      end

      private

      def resolve_literal(node, registry)
        node => AST::Literal(value:)

        symbol =
          case value
          in Integer
            Symbol::TypeRef['Basics.Int']

          in TrueClass | FalseClass
            Symbol::TypeRef['Basics.Bool']

          in String
            Symbol::TypeRef['String.String']
          end

        node.with(symbol:)
      end
    end
  end
end

module Jade
  module Symbol
    module Parser
      extend self
      include Parsing::Combinators
      include Parsing::Token
      include Parsing::Type

      def parse(tokens)
        type_expression
          .call(State.new(tokens))
          .map(&:first) => Ok(node)

        to_symbol(node)
      end

      private

      def to_symbol(node)
        case node
        in AST::TypeApplication(constructor: AST::TypeVar(type: name), args:)
          Symbol.partial_application(Symbol.var(name, nil), args.map(&method(:to_symbol)), nil)

        in AST::TypeApplication(constructor:, args:)
          Symbol.type_application(Symbol.type_ref(*qualify(constructor.type)), args.map(&method(:to_symbol)), nil)

        in AST::TypeVar(type:)
          Symbol.var(type, nil)

        in AST::TypeFunction(params:, return_type:)
          Symbol
            .function_type(
              params.map { to_symbol(it) },
              to_symbol(return_type)
            )
        end
      end

      def qualify(type)
        case type
        in 'Int' | 'Float' | 'Bool' | 'Ordering'
          'Basics'

        in 'String' | 'Maybe' | 'List'
          type

        in 'Tuple2' | 'Tuple3' | 'Tuple4'
          'Tuple'

        end
          .then { [it, type] }
      end
    end
  end
end

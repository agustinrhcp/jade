require 'jade/type'

module Jade
  module TypeFactory
    refine Type.singleton_class do
      def maybe(inner)
        Type.constructor('Maybe.Maybe').apply([inner])
      end

      def list(inner)
        Type.constructor('List.List').apply([inner])
      end

      def eq(type)
        Type.constraint('Basics.Eq', type, nil)
      end

      def ord_constraint
        Type.constraint(Symbol.type_ref('Basics', 'Ord'), Type.var('a'))
      end

      def parse(annotation)
        Lexer
          .tokenize(Source.new(uri: nil, text: annotation))
          .then { TypeFactory::Parser.parse(it) }
      end
    end
  end
end

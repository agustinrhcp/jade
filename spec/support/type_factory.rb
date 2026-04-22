require 'jade/type'

module Jade
  module TypeFactory
    refine Type.singleton_class do
      def never
        Type.constructor('Basics.Never').apply([])
      end

      def maybe(inner)
        Type.constructor('Maybe.Maybe').apply([inner])
      end

      def list(inner)
        Type.constructor('List.List').apply([inner])
      end

      def parse(annotation)
        Lexer
          .tokenize(Source.new(uri: nil, text: annotation))
          .then { TypeFactory::Parser.parse(it) }
      end

      def eq(type)
        Type.constraint('Basics.Eq', type, nil)
      end
    end
  end
end

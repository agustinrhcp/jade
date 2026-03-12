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

      def parse(annotation)
        Lexer
          .tokenize(Source.new(uri: nil, text: annotation))
          .then { TypeFactory::Parser.parse(it) }
      end
    end
  end
end

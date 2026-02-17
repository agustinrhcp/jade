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
    end
  end
end

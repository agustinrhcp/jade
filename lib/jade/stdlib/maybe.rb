require 'jade/stdlib/compiled'

module Jade
  module Stdlib
    module Maybe
      extend self
      extend Compiled

      def uri
        'maybe.jd'
      end

      def imports
        [Basics]
      end

      def default_imports
        [
          Symbol.type_ref('Maybe', 'Maybe'),
          Symbol.value_ref('Maybe', 'Just'),
          Symbol.value_ref('Maybe', 'Nothing'),
        ]
      end

      def code
        <<~JADE
          module Maybe exposing (Maybe(..), and_then, map, with_default)

          type Maybe(a)
            = Just(a)
            | Nothing


          def with_default(maybe: Maybe(a), default: a) -> a
            case maybe
            of Just(something) -> something
            of Nothing -> default


          def map(maybe: Maybe(a), fn: a -> b) -> Maybe(b)
            case maybe
            of Just(something) -> something
              |> fn
              |> Just
            of Nothing -> maybe


          def and_then(maybe: Maybe(a), fn: a -> Maybe(b)) -> Maybe(b)
            case maybe
            of Just(something) -> something |> fn
            of Nothing -> Nothing


          implements Mappable(Maybe(a)) with
            map: map


          implements Chainable(Maybe(a)) with
            and_then: and_then
        JADE
      end
    end
  end
end

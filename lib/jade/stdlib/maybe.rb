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
          module Maybe exposing(Maybe(..), with_default, map, and_then)

          type Maybe(a) = Just(a) | Nothing

          def with_default(maybe: Maybe(a), default: a) -> a
            case maybe
            of Just(something) then something
            of Nothing then default
            end
          end

          def map(maybe: Maybe(a), fn: a -> b) -> Maybe(b)
            case maybe
            of Just(something) then
              something |> fn |> Just

            of Nothing then maybe
            end
          end

          def and_then(maybe: Maybe(a), fn: a -> Maybe(b)) -> Maybe(b)
            case maybe
            of Just(something) then
              something |> fn

            of Nothing then Nothing()
            end
          end
        JADE
      end
    end
  end
end

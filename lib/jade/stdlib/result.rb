require 'jade/stdlib/compiled'

module Jade
  module Stdlib
    module Result
      extend self
      extend Compiled

      def uri
        'result.jd'
      end

      def imports
        [Basics, Maybe]
      end

      def default_imports
        ['Result', 'Ok', 'Err']
      end

      def code
        <<~JADE
          module Result exposing(Result, map, and_then, with_default, to_maybe, from_maybe, map_error)

          type Result(value, error) = Ok(value) | Err(error)

          def map(result: Result(a, e), fn: a -> b) -> Result(b, e)
            case result
            of Ok(something) then
              something |> fn |> Ok

            of Err(_) then result
            end
          end

          def and_then(result: Result(a, e), fn: a -> Result(b, e)) -> Result(b, e)
            case result
            of Ok(something) then
              something |> fn

            of Err(_) then result
            end
          end

          def with_default(result: Result(a, e), default: a) -> a
            case result
            of Ok(something) then something
            of _ then default
            end
          end

          def to_maybe(result: Result(a, e)) -> Maybe(a)
            case result
            of Ok(something) then Just(something)
            of _ then Nothing()
            end
          end

          def from_maybe(maybe: Maybe(a), error: e) -> Result(a, e)
            case maybe
            of Just(something) then Ok(something)
            of Nothing then Err(error)
            end
          end

          def map_error(result: Result(a, e), fn: e -> x) -> Result(a, x)
            case result
            of Err(error) then error |> fn |> Err
            of _ then result
            end
          end
        JADE
      end
    end
  end
end

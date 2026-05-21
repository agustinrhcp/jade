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
        [Basics, Maybe, List]
      end

      def default_imports
        [
          Symbol.type_ref('Result', 'Result'),
          Symbol.value_ref('Result', 'Ok'),
          Symbol.value_ref('Result', 'Err'),
        ]
      end

      def code
        <<~JADE
          module Result exposing (
            Result(..),
            and_then,
            from_maybe,
            map,
            map_error,
            on_error,
            sequence,
            to_maybe,
            with_default,
          )

          type Result(value, error)
            = Ok(value)
            | Err(error)


          def map(result: Result(a, e), fn: a -> b) -> Result(b, e)
            case result
            of Ok(something) -> something
              |> fn
              |> Ok
            of Err(error) -> Err(error)


          def and_then(result: Result(a, e), fn: a -> Result(b, e)) -> Result(b, e)
            case result
            of Ok(something) -> something |> fn
            of Err(error) -> Err(error)


          def with_default(result: Result(a, e), default: a) -> a
            case result
            of Ok(something) -> something
            of _ -> default


          def to_maybe(result: Result(a, e)) -> Maybe(a)
            case result
            of Ok(something) -> Just(something)
            of _ -> Nothing


          def from_maybe(maybe: Maybe(a), error: e) -> Result(a, e)
            case maybe
            of Just(something) -> Ok(something)
            of Nothing -> Err(error)


          def map_error(result: Result(a, e), fn: e -> x) -> Result(a, x)
            case result
            of Err(error) -> error
              |> fn
              |> Err
            of Ok(something) -> Ok(something)


          def sequence(results: List(Result(a, e))) -> Result(List(a), e)
            List.fold(
              results,
              Ok([]),
              (acc, result) -> {
                list <- acc
                value <- result

                Ok(list ++ [value])
              },
            )


          def on_error(result: Result(a, e), fn: e -> Result(a, f)) -> Result(a, f)
            case result
            of Err(error) -> error |> fn
            of Ok(_) -> result


          implements Mappable(Result(a, e)) with
            map: map


          implements Chainable(Result(a, e)) with
            and_then: and_then
        JADE
      end
    end
  end
end

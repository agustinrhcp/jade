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
            in Ok(something)
              something
                |> fn
                |> Ok
            in Err(error) then Err(error)
            end
          end


          def and_then(result: Result(a, e), fn: a -> Result(b, e)) -> Result(b, e)
            case result
            in Ok(something) then something |> fn
            in Err(error) then Err(error)
            end
          end


          def with_default(result: Result(a, e), default: a) -> a
            case result
            in Ok(something) then something
            else default
            end
          end


          def to_maybe(result: Result(a, e)) -> Maybe(a)
            case result
            in Ok(something) then Just(something)
            else Nothing
            end
          end


          def from_maybe(maybe: Maybe(a), error: e) -> Result(a, e)
            case maybe
            in Just(something) then Ok(something)
            in Nothing then Err(error)
            end
          end


          def map_error(result: Result(a, e), fn: e -> x) -> Result(a, x)
            case result
            in Err(error)
              error
                |> fn
                |> Err
            in Ok(something) then Ok(something)
            end
          end


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
          end


          def on_error(result: Result(a, e), fn: e -> Result(a, f)) -> Result(a, f)
            case result
            in Err(error) then error |> fn
            in Ok(_) then result
            end
          end


          implements Mappable(Result(a, e)) with
            map: map
          end


          implements Chainable(Result(a, e)) with
            and_then: and_then
          end
        JADE
      end
    end
  end
end

require 'jade/stdlib/compiled'

module Jade
  module Stdlib
    module Decode
      module Params
        extend self
        extend Compiled

        def uri
          'decode/params.jd'
        end

        def imports
          [Basics, Maybe, List, Tuple, Stdlib::String, Stdlib::Decode]
        end

        def default_imports
          []
        end

        def code
          <<~JADE
            module Decode.Params exposing (
              Params(..),
              accept,
              bool,
              collect,
              default,
              empty,
              float,
              int,
              nested,
              string,
            )

            import Decode exposing (Decoder)


            type Params(a) = Params(List((String, Decoder(a))), List((String, a)))


            def empty -> Params(a)
              Params([], [])
            end


            def accept(p: Params(a), key: String, decoder: Decoder(a)) -> Params(a)
              case p
              in Params(accs, defs) then Params(accs ++ [(key, decoder)], defs)
              end
            end


            def default(p: Params(a), key: String, value: a) -> Params(a)
              case p
              in Params(accs, defs) then Params(accs, defs ++ [(key, value)])
              end
            end


            def string(p: Params(a), key: String, ctor: String -> a) -> Params(a)
              accept(p, key, Decode.map(Decode.string, ctor))
            end


            def int(p: Params(a), key: String, ctor: Int -> a) -> Params(a)
              accept(p, key, Decode.map(Decode.int, ctor))
            end


            def float(p: Params(a), key: String, ctor: Float -> a) -> Params(a)
              accept(p, key, Decode.map(Decode.float, ctor))
            end


            def bool(p: Params(a), key: String, ctor: Bool -> a) -> Params(a)
              accept(p, key, Decode.map(Decode.bool, ctor))
            end


            def nested(
              p: Params(a),
              key: String,
              ctor: List(b) -> a,
              sub: Params(b),
            ) -> Params(a)
              accept(p, key, Decode.map(collect(sub), ctor))
            end


            def collect(p: Params(a)) -> Decoder(List(a))
              case p
              in Params(accs, defs)
                accs
                  |> List.map((acc) -> { accept_to_decoder(defs, acc) })
                  |> Decode.sequence
                  |> Decode.map(filter_justs)
              end
            end


            def accept_to_decoder(
              defs: List((String, a)),
              acc: (String, Decoder(a)),
            ) -> Decoder(Maybe(a))
              key = Tuple.first(acc)
              decoder = Tuple.second(acc)
              raw = Decode.optional_field(key, decoder)
              case lookup_default(defs, key)
              in Just(v) then with_default(raw, v)
              in Nothing then raw
              end
            end


            def with_default(decoder: Decoder(Maybe(a)), v: a) -> Decoder(Maybe(a))
              Decode.map(decoder, (m) -> { maybe_or_just(m, v) })
            end


            def maybe_or_just(m: Maybe(a), v: a) -> Maybe(a)
              case m
              in Just(_) then m
              in Nothing then Just(v)
              end
            end


            def filter_justs(maybes: List(Maybe(a))) -> List(a)
              List.and_then(maybes, maybe_to_list)
            end


            def maybe_to_list(m: Maybe(a)) -> List(a)
              case m
              in Just(x) then [x]
              in Nothing then []
              end
            end


            def lookup_default(defs: List((String, a)), key: String) -> Maybe(a)
              case defs
              in [] then Nothing
              in [(k, v) | rest] then k == key ? Just(v) : lookup_default(rest, key)
              end
            end
          JADE
        end
      end
    end
  end
end

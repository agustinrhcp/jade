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


            def accept(p: Params(a), key: String, decoder: Decoder(a)) -> Params(a)
              case p
              of Params(accs, defs) -> Params(accs ++ [(key, decoder)], defs)


            def default(p: Params(a), key: String, value: a) -> Params(a)
              case p
              of Params(accs, defs) -> Params(accs, defs ++ [(key, value)])


            def string(p: Params(a), key: String, ctor: String -> a) -> Params(a)
              accept(p, key, Decode.map(Decode.string, ctor))


            def int(p: Params(a), key: String, ctor: Int -> a) -> Params(a)
              accept(p, key, Decode.map(Decode.int, ctor))


            def float(p: Params(a), key: String, ctor: Float -> a) -> Params(a)
              accept(p, key, Decode.map(Decode.float, ctor))


            def bool(p: Params(a), key: String, ctor: Bool -> a) -> Params(a)
              accept(p, key, Decode.map(Decode.bool, ctor))


            def nested(
              p: Params(a),
              key: String,
              ctor: List(b) -> a,
              sub: Params(b),
            ) -> Params(a)
              accept(p, key, Decode.map(collect(sub), ctor))


            def collect(p: Params(a)) -> Decoder(List(a))
              case p
              of Params(accs, defs) ->
                decoders = List.map(accs, (acc) -> { accept_to_decoder(defs, acc) })

                Decode.map(Decode.sequence(decoders), filter_justs)


            def accept_to_decoder(
              defs: List((String, a)),
              acc: (String, Decoder(a)),
            ) -> Decoder(Maybe(a))
              key = Tuple.first(acc)
              decoder = Tuple.second(acc)
              raw = Decode.optional_field(key, decoder)

              case lookup_default(defs, key)
              of Just(v) -> with_default(raw, v)
              of Nothing -> raw


            def with_default(decoder: Decoder(Maybe(a)), v: a) -> Decoder(Maybe(a))
              Decode.map(decoder, (m) -> { maybe_or_just(m, v) })


            def maybe_or_just(m: Maybe(a), v: a) -> Maybe(a)
              case m
              of Just(_) -> m
              of Nothing -> Just(v)


            def filter_justs(maybes: List(Maybe(a))) -> List(a)
              List.and_then(maybes, maybe_to_list)


            def maybe_to_list(m: Maybe(a)) -> List(a)
              case m
              of Just(x) -> [x]
              of Nothing -> []


            def lookup_default(defs: List((String, a)), key: String) -> Maybe(a)
              case defs
              of [] -> Nothing
              of [(k, v) | rest] -> if k == key then Just(v) else lookup_default(rest, key)
          JADE
        end
      end
    end
  end
end

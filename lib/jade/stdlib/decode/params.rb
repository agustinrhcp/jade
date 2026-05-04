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
            module Decode.Params exposing(Params(..), empty, accept, default, string, int, float, bool, nested, collect)

            import Decode exposing(Decoder)

            type Params(a) = Params(List((String, Decoder(a))), List((String, a)))

            def empty() -> Params(a)
              Params([], [])
            end

            def accept(p: Params(a), key: String, decoder: Decoder(a)) -> Params(a)
              case p
              of Params(accs, defs) then Params(accs ++ [(key, decoder)], defs)
              end
            end

            def default(p: Params(a), key: String, value: a) -> Params(a)
              case p
              of Params(accs, defs) then Params(accs, defs ++ [(key, value)])
              end
            end

            def string(p: Params(a), key: String, ctor: String -> a) -> Params(a)
              accept(p, key, Decode.map(ctor, Decode.string))
            end

            def int(p: Params(a), key: String, ctor: Int -> a) -> Params(a)
              accept(p, key, Decode.map(ctor, Decode.int))
            end

            def float(p: Params(a), key: String, ctor: Float -> a) -> Params(a)
              accept(p, key, Decode.map(ctor, Decode.float))
            end

            def bool(p: Params(a), key: String, ctor: Bool -> a) -> Params(a)
              accept(p, key, Decode.map(ctor, Decode.bool))
            end

            def nested(p: Params(a), key: String, ctor: List(b) -> a, sub: Params(b)) -> Params(a)
              accept(p, key, Decode.map(ctor, collect(sub)))
            end

            def collect(p: Params(a)) -> Decoder(List(a))
              case p
              of Params(accs, defs) then
                decoders = List.map(accs, (acc) -> { accept_to_decoder(defs, acc) })
                Decode.map(filter_justs, Decode.sequence(decoders))
              end
            end

            def accept_to_decoder(defs: List((String, a)), acc: (String, Decoder(a))) -> Decoder(Maybe(a))
              key = Tuple.first(acc)
              decoder = Tuple.second(acc)
              raw = Decode.optional_field(key, decoder)
              case lookup_default(defs, key)
              of Just(v) then with_default(raw, v)
              of Nothing then raw
              end
            end

            def with_default(decoder: Decoder(Maybe(a)), v: a) -> Decoder(Maybe(a))
              Decode.map((m) -> { maybe_or_just(m, v) }, decoder)
            end

            def maybe_or_just(m: Maybe(a), v: a) -> Maybe(a)
              case m
              of Just(_) then m
              of Nothing then Just(v)
              end
            end

            def filter_justs(maybes: List(Maybe(a))) -> List(a)
              List.and_then(maybes, maybe_to_list)
            end

            def maybe_to_list(m: Maybe(a)) -> List(a)
              case m
              of Just(x) then [x]
              of Nothing then []
              end
            end

            def lookup_default(defs: List((String, a)), key: String) -> Maybe(a)
              case defs
              of [] then Nothing
              of [(k, v) | rest] then
                if k == key then
                  Just(v)
                else
                  lookup_default(rest, key)
                end
              end
            end
          JADE
        end
      end
    end
  end
end

require 'jade/stdlib/intrinsics'
require 'jade/decode'

module Jade
  module Stdlib
    module Decode
      extend Intrinsics

      import Maybe
      import Result
      import List
      import Dict

      union :DecodeError
      variant :MissingField, of: :DecodeError, args: ['String']
      variant :WrongType,    of: :DecodeError, args: ['String', 'String']
      variant :AtField,      of: :DecodeError, args: ['String', 'DecodeError']
      variant :AtIndex,      of: :DecodeError, args: ['Int', 'DecodeError']
      variant :Multiple,     of: :DecodeError, args: ['List(DecodeError)']
      variant :Custom,       of: :DecodeError, args: ['String']

      union :Value
      union :Decoder, 'a'

      interface(
        'Decodable',
        'a',
        { 'decoder' => 'Decoder(a)' },
      )

      # Primitives

      function('string', {}, 'Decoder(String)') {
        Jade::Decode::Decoder[Jade::Decode::Desc::Str[]]
      }

      function('int', {}, 'Decoder(Int)') {
        Jade::Decode::Decoder[Jade::Decode::Desc::Int[]]
      }

      function('float', {}, 'Decoder(Float)') {
        Jade::Decode::Decoder[Jade::Decode::Desc::Flt[]]
      }

      function('bool', {}, 'Decoder(Bool)') {
        Jade::Decode::Decoder[Jade::Decode::Desc::Bool[]]
      }

      # Structural

      function(
        'nullable',
        { decoder: 'Decoder(a)' },
        'Decoder(Maybe(a))',
      ) { |decoder|
        Jade::Decode::Decoder[Jade::Decode::Desc::Nullable[decoder.desc]]
      }

      function(
        'field',
        { key: 'String', decoder: 'Decoder(a)' },
        'Decoder(a)',
      ) { |key, decoder|
        Jade::Decode::Decoder[Jade::Decode::Desc::Field[key, decoder.desc]]
      }

      function(
        'optional_field',
        { key: 'String', decoder: 'Decoder(a)' },
        'Decoder(Maybe(a))',
      ) { |key, decoder|
        Jade::Decode::Decoder[Jade::Decode::Desc::OptField[key, decoder.desc]]
      }

      function(
        'index',
        { i: 'Int', decoder: 'Decoder(a)' },
        'Decoder(a)',
      ) { |i, decoder|
        Jade::Decode::Decoder[Jade::Decode::Desc::Idx[i, decoder.desc]]
      }

      function(
        'list',
        { decoder: 'Decoder(a)' },
        'Decoder(List(a))',
      ) { |decoder|
        Jade::Decode::Decoder[Jade::Decode::Desc::Lst[decoder.desc]]
      }

      # Decodes either a Hash (natural Ruby/JSON object form) or a list
      # of `[k, v]` pairs (what Encode.dict emits — also the only shape
      # that round-trips non-String key types).
      function(
        'dict',
        { k_dec: 'Decoder(k)', v_dec: 'Decoder(v)' },
        'Decoder(Dict(k, v))',
      ) { |k_dec, v_dec|
        Jade::Decode::Decoder[Jade::Decode::Desc::Dct[k_dec.desc, v_dec.desc]]
      }

      # Mapping

      function(
        'map',
        { decoder: 'Decoder(a)', fn: 'a -> b' },
        'Decoder(b)',
      ) { |decoder, fn|
        Jade::Decode::Decoder[Jade::Decode::Desc::Map[fn, decoder.desc]]
      }

      # Pipeline

      function(
        'succeed',
        { value: 'a' },
        'Decoder(a)',
      ) { |value|
        Jade::Decode::Decoder[Jade::Decode::Desc::Succeed[value]]
      }

      function(
        'and_map',
        { wrapped: 'Decoder(a -> b)', decoder: 'Decoder(a)' },
        'Decoder(b)',
      ) { |wrapped, decoder|
        Jade::Decode::Decoder[Jade::Decode::Desc::AndMap[wrapped.desc, decoder.desc]]
      }

      function(
        'required',
        { wrapped: 'Decoder(a -> b)', key: 'String', field_decoder: 'Decoder(a)' },
        'Decoder(b)',
      ) { |wrapped, key, field_decoder|
        Jade::Decode::Desc::Field[key, field_decoder.desc]
          .then { Jade::Decode::Decoder[Jade::Decode::Desc::AndMap[wrapped.desc, it]] }
      }

      function(
        'optional',
        {
          wrapped: 'Decoder(a -> b)',
          key: 'String',
          field_decoder: 'Decoder(a)',
          default: 'a',
        },
        'Decoder(b)',
      ) { |wrapped, key, field_decoder, default|
        Jade::Decode::Desc::Optional[key, field_decoder.desc, default]
          .then { Jade::Decode::Decoder[Jade::Decode::Desc::AndMap[wrapped.desc, it]] }
      }

      function(
        'sequence',
        { decoders: 'List(Decoder(a))' },
        'Decoder(List(a))',
      ) { |decoders|
        Jade::Decode::Decoder[Jade::Decode::Desc::Sequence[decoders.map(&:desc)]]
      }

      function(
        'one_of',
        { decoders: 'List(Decoder(a))' },
        'Decoder(a)',
      ) { |decoders|
        Jade::Decode::Decoder[Jade::Decode::Desc::OneOf[decoders.map(&:desc)]]
      }

      function(
        'and_then',
        { decoder: 'Decoder(a)', fn: 'a -> Decoder(b)' },
        'Decoder(b)',
      ) { |decoder, fn|
        Jade::Decode::Decoder[Jade::Decode::Desc::AndThen[fn, decoder.desc]]
      }

      function(
        'fail',
        { msg: 'String' },
        'Decoder(a)',
      ) { |msg|
        Jade::Decode::Decoder[Jade::Decode::Desc::Fail[msg]]
      }

      function(
        'from_result',
        { r: 'Result(a, String)' },
        'Decoder(a)',
      ) { |r|
        case r
        in Jade::Result::Ok[v]   then Jade::Decode::Decoder[Jade::Decode::Desc::Succeed[v]]
        in Jade::Result::Err[e]  then Jade::Decode::Decoder[Jade::Decode::Desc::Fail[e]]
        end
      }

      # Entry points

      function(
        'decode',
        { decoder: 'Decoder(a)', value: 'Value' },
        'Result(a, DecodeError)',
      ) { |decoder, value|
        Jade::Decode::Runner.run(decoder, value)
      }

      function(
        'decode_string',
        { decoder: 'Decoder(a)', json: 'String' },
        'Result(a, DecodeError)',
      ) { |decoder, json|
        Jade::Decode::Runner.from_json(decoder, json)
      }

      # Constrained helpers — pick the decoder via Decodable.

      function(
        'from_value',
        { value: 'Value' },
        'Result(a, DecodeError)',
        constraints: [['Decode.Decodable', 'a']],
        body: Symbol::DerivedFunction.new(
          params: ['value'],
          body: [:call,
            [:stdlib_fn, 'Decode.decode'],
            [
              [:impl_arg, 0, 'decoder'],
              [:var, 'value'],
            ],
          ],
        ),
      )

      function(
        'from_json',
        { json: 'String' },
        'Result(a, DecodeError)',
        constraints: [['Decode.Decodable', 'a']],
        body: Symbol::DerivedFunction.new(
          params: ['json'],
          body: [:call,
            [:stdlib_fn, 'Decode.decode_string'],
            [
              [:impl_arg, 0, 'decoder'],
              [:var, 'json'],
            ],
          ],
        ),
      )

      # Builder seed for `[name, ...args]`-shape union decoding. Compose
      # with `variant` via `|>`:
      #   Decode.type_
      #     |> Decode.variant("A", ...)
      #     |> Decode.variant("B", ...)
      function('type_', {}, 'Decoder(a)') {
        Jade::Decode::Decoder[Jade::Decode::Desc::Variant[{}]]
      }

      function(
        'variant',
        { builder: 'Decoder(a)', name: 'String', decoder: 'Decoder(a)' },
        'Decoder(a)',
      ) { |builder, name, decoder|
        builder.desc => Jade::Decode::Desc::Variant[cases]
        cases
          .merge(name => decoder.desc)
          .then { Jade::Decode::Desc::Variant[it] }
          .then { Jade::Decode::Decoder[it] }
      }

      function(
        'tuple',
        { a: 'Decoder(a)', b: 'Decoder(b)' },
        'Decoder(Tuple2(a, b))',
      ) { |da, db|
        Jade::Decode::Desc::Succeed[Jade::Tuple::Tuple2.method(:[]).curry(2)]
          .then { Jade::Decode::Desc::AndMap[it, Jade::Decode::Desc::Idx[0, da.desc]] }
          .then { Jade::Decode::Desc::AndMap[it, Jade::Decode::Desc::Idx[1, db.desc]] }
          .then { Jade::Decode::Decoder[it] }
      }

      function(
        'tuple3',
        { a: 'Decoder(a)', b: 'Decoder(b)', c: 'Decoder(c)' },
        'Decoder(Tuple3(a, b, c))',
      ) { |da, db, dc|
        Jade::Decode::Desc::Succeed[Jade::Tuple::Tuple3.method(:[]).curry(3)]
          .then { Jade::Decode::Desc::AndMap[it, Jade::Decode::Desc::Idx[0, da.desc]] }
          .then { Jade::Decode::Desc::AndMap[it, Jade::Decode::Desc::Idx[1, db.desc]] }
          .then { Jade::Decode::Desc::AndMap[it, Jade::Decode::Desc::Idx[2, dc.desc]] }
          .then { Jade::Decode::Decoder[it] }
      }

      function(
        'tuple4',
        { a: 'Decoder(a)', b: 'Decoder(b)', c: 'Decoder(c)', d: 'Decoder(d)' },
        'Decoder(Tuple4(a, b, c, d))',
      ) { |da, db, dc, dd|
        Jade::Decode::Desc::Succeed[Jade::Tuple::Tuple4.method(:[]).curry(4)]
          .then { Jade::Decode::Desc::AndMap[it, Jade::Decode::Desc::Idx[0, da.desc]] }
          .then { Jade::Decode::Desc::AndMap[it, Jade::Decode::Desc::Idx[1, db.desc]] }
          .then { Jade::Decode::Desc::AndMap[it, Jade::Decode::Desc::Idx[2, dc.desc]] }
          .then { Jade::Decode::Desc::AndMap[it, Jade::Decode::Desc::Idx[3, dd.desc]] }
          .then { Jade::Decode::Decoder[it] }
      }

      # Primitive Decodable impls.

      implementation('Decodable', 'Basics.Int',    'decoder' => 'int')
      implementation('Decodable', 'Basics.Float',  'decoder' => 'float')
      implementation('Decodable', 'Basics.Bool',   'decoder' => 'bool')
      implementation('Decodable', 'String.String', 'decoder' => 'string')
    end
  end
end

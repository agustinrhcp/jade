require 'jade/stdlib/intrinsics'
require 'jade/decode'

module Jade
  module Stdlib
    module Decode
      extend Intrinsics

      import Maybe
      import Result
      import List

      union :DecodeError
      variant :MissingField, of: :DecodeError, args: ['String']
      variant :WrongType,    of: :DecodeError, args: ['String', 'String']
      variant :AtField,      of: :DecodeError, args: ['String', 'DecodeError']
      variant :AtIndex,      of: :DecodeError, args: ['Int', 'DecodeError']
      variant :Multiple,     of: :DecodeError, args: ['List(DecodeError)']

      union :Value
      union :Decoder, 'a'

      interface(
        'Decodable',
        'a',
        { 'decoder' => '() -> Decoder(a)' },
      )

      # Primitives

      function('string', {}, 'Decoder(String)') {
        ::Decode::Decoder[::Decode::Desc::Str[]]
      }

      function('int', {}, 'Decoder(Int)') {
        ::Decode::Decoder[::Decode::Desc::Int[]]
      }

      function('float', {}, 'Decoder(Float)') {
        ::Decode::Decoder[::Decode::Desc::Flt[]]
      }

      function('bool', {}, 'Decoder(Bool)') {
        ::Decode::Decoder[::Decode::Desc::Bool[]]
      }

      # Structural

      function(
        'nullable',
        { decoder: 'Decoder(a)' },
        'Decoder(Maybe(a))',
      ) { |decoder|
        ::Decode::Decoder[::Decode::Desc::Nullable[decoder.desc]]
      }

      function(
        'field',
        { key: 'String', decoder: 'Decoder(a)' },
        'Decoder(a)',
      ) { |key, decoder|
        ::Decode::Decoder[::Decode::Desc::Field[key, decoder.desc]]
      }

      function(
        'optional_field',
        { key: 'String', decoder: 'Decoder(a)' },
        'Decoder(Maybe(a))',
      ) { |key, decoder|
        ::Decode::Decoder[::Decode::Desc::OptField[key, decoder.desc]]
      }

      function(
        'index',
        { i: 'Int', decoder: 'Decoder(a)' },
        'Decoder(a)',
      ) { |i, decoder|
        ::Decode::Decoder[::Decode::Desc::Idx[i, decoder.desc]]
      }

      function(
        'list',
        { decoder: 'Decoder(a)' },
        'Decoder(List(a))',
      ) { |decoder|
        ::Decode::Decoder[::Decode::Desc::Lst[decoder.desc]]
      }

      # Mapping

      function(
        'map',
        { fn: 'a -> b', decoder: 'Decoder(a)' },
        'Decoder(b)',
      ) { |fn, decoder|
        ::Decode::Decoder[::Decode::Desc::Map[fn, decoder.desc]]
      }

      # Pipeline

      function(
        'succeed',
        { value: 'a' },
        'Decoder(a)',
      ) { |value|
        ::Decode::Decoder[::Decode::Desc::Succeed[value]]
      }

      function(
        'and_map',
        { wrapped: 'Decoder(a -> b)', decoder: 'Decoder(a)' },
        'Decoder(b)',
      ) { |wrapped, decoder|
        ::Decode::Decoder[::Decode::Desc::AndMap[wrapped.desc, decoder.desc]]
      }

      function(
        'required',
        { wrapped: 'Decoder(a -> b)', key: 'String', field_decoder: 'Decoder(a)' },
        'Decoder(b)',
      ) { |wrapped, key, field_decoder|
        ::Decode::Desc::Field[key, field_decoder.desc]
          .then { ::Decode::Decoder[::Decode::Desc::AndMap[wrapped.desc, it]] }
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
        ::Decode::Desc::Optional[key, field_decoder.desc, default]
          .then { ::Decode::Decoder[::Decode::Desc::AndMap[wrapped.desc, it]] }
      }

      function(
        'sequence',
        { decoders: 'List(Decoder(a))' },
        'Decoder(List(a))',
      ) { |decoders|
        ::Decode::Decoder[::Decode::Desc::Sequence[decoders.map(&:desc)]]
      }

      function(
        'one_of',
        { decoders: 'List(Decoder(a))' },
        'Decoder(a)',
      ) { |decoders|
        ::Decode::Decoder[::Decode::Desc::OneOf[decoders.map(&:desc)]]
      }

      # Entry points

      function(
        'decode',
        { decoder: 'Decoder(a)', value: 'Value' },
        'Result(a, DecodeError)',
      ) { |decoder, value|
        ::Decode::Runner.run(decoder, value._1)
      }

      function(
        'decode_string',
        { decoder: 'Decoder(a)', json: 'String' },
        'Result(a, DecodeError)',
      ) { |decoder, json|
        ::Decode::Runner.from_json(decoder, json)
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
              [:call, [:impl_arg, 0, 'decoder'], []],
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
              [:call, [:impl_arg, 0, 'decoder'], []],
              [:var, 'json'],
            ],
          ],
        ),
      )

      # Primitive Decodable impls.

      implementation('Decodable', 'Basics.Int',    'decoder' => 'int')
      implementation('Decodable', 'Basics.Float',  'decoder' => 'float')
      implementation('Decodable', 'Basics.Bool',   'decoder' => 'bool')
      implementation('Decodable', 'String.String', 'decoder' => 'string')
    end
  end
end

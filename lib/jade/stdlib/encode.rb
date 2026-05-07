require 'json'
require 'jade/stdlib/intrinsics'

module Jade
  module Stdlib
    module Encode
      extend Intrinsics

      import Maybe
      import List
      import Tuple

      interface(
        'Encodable',
        'a',
        { 'encoder' => 'a -> Value' },
      )

      # Primitives

      function('string', { s: 'String' }, 'Value') { it.dup }
      function('int', { i: 'Int' }, 'Value') { it }
      function('float', { f: 'Float' }, 'Value') { it.to_f }
      function('bool', { b: 'Bool' }, 'Value') { it }
      function('null', {}, 'Value') { nil }

      # Structural

      function(
        'nullable',
        { encoder: 'a -> Value', maybe: 'Maybe(a)' },
        'Value',
      ) { |encoder, maybe|
        case maybe
        in Jade::Maybe::Just[v] then encoder.call(v)
        in Jade::Maybe::Nothing then nil
        end
      }

      function(
        'list',
        { encoder: 'a -> Value', items: 'List(a)' },
        'Value',
      ) { |encoder, items|
        items.map { encoder.call(it) }
      }

      function(
        'object',
        { pairs: 'List(Tuple2(String, Value))' },
        'Value',
      ) { |pairs|
        pairs
          .each_with_object({}) { |pair, acc| acc[pair._1] = pair._2 }
      }

      function(
        'field',
        { key: 'String', encoder: 'a -> Value', value: 'a' },
        'Tuple2(String, Value)',
      ) { |key, encoder, value|
        Jade::Tuple::Tuple2[key.dup, encoder.call(value)]
      }

      function(
        'encode_to_string',
        { value: 'Value' },
        'String',
      ) { |value|
        JSON.generate(value)
      }

      # Constrained — picks the encoder via Encodable.

      function(
        'encode',
        { x: 'a' },
        'Value',
        constraints: [['Encode.Encodable', 'a']],
        body: Symbol::DerivedFunction.new(
          params: ['x'],
          body: [:call,
            [:impl_arg, 0, 'encoder'],
            [[:var, 'x']],
          ],
        ),
      )

      # Primitive Encodable impls.

      implementation('Encodable', 'Basics.Int',    'encoder' => 'int')
      implementation('Encodable', 'Basics.Float',  'encoder' => 'float')
      implementation('Encodable', 'Basics.Bool',   'encoder' => 'bool')
      implementation('Encodable', 'String.String', 'encoder' => 'string')
    end
  end
end

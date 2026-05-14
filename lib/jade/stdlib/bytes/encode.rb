require 'jade/stdlib/intrinsics'
require 'jade/stdlib/bytes'

module Jade
  module Stdlib
    module Bytes
      module Encode
        extend Intrinsics

        def self.module_name = 'Bytes.Encode'

        import Basics
        import List
        import Bytes

        union :Encoder

        function(
          'encode',
          { encoder: 'Bytes.Encode.Encoder' },
          'Bytes.Bytes',
        ) { |e| Jade::Bytes::Bytes[e.bin] }

        function(
          'signed_int8',
          { n: 'Int' },
          'Bytes.Encode.Encoder',
        ) { |n| Jade::Bytes::Encode::Encoder[[n].pack('c')] }

        function(
          'unsigned_int8',
          { n: 'Int' },
          'Bytes.Encode.Encoder',
        ) { |n| Jade::Bytes::Encode::Encoder[[n].pack('C')] }

        function(
          'signed_int16',
          { endianness: 'Bytes.Endianness', n: 'Int' },
          'Bytes.Encode.Encoder',
        ) { |e, n|
          fmt = e.is_a?(Jade::Bytes::LE) ? 's<' : 's>'
          Jade::Bytes::Encode::Encoder[[n].pack(fmt)]
        }

        function(
          'unsigned_int16',
          { endianness: 'Bytes.Endianness', n: 'Int' },
          'Bytes.Encode.Encoder',
        ) { |e, n|
          fmt = e.is_a?(Jade::Bytes::LE) ? 'S<' : 'S>'
          Jade::Bytes::Encode::Encoder[[n].pack(fmt)]
        }

        function(
          'signed_int32',
          { endianness: 'Bytes.Endianness', n: 'Int' },
          'Bytes.Encode.Encoder',
        ) { |e, n|
          fmt = e.is_a?(Jade::Bytes::LE) ? 'l<' : 'l>'
          Jade::Bytes::Encode::Encoder[[n].pack(fmt)]
        }

        function(
          'unsigned_int32',
          { endianness: 'Bytes.Endianness', n: 'Int' },
          'Bytes.Encode.Encoder',
        ) { |e, n|
          fmt = e.is_a?(Jade::Bytes::LE) ? 'L<' : 'L>'
          Jade::Bytes::Encode::Encoder[[n].pack(fmt)]
        }

        function(
          'float32',
          { endianness: 'Bytes.Endianness', f: 'Float' },
          'Bytes.Encode.Encoder',
        ) { |e, f|
          fmt = e.is_a?(Jade::Bytes::LE) ? 'e' : 'g'
          Jade::Bytes::Encode::Encoder[[f].pack(fmt)]
        }

        function(
          'float64',
          { endianness: 'Bytes.Endianness', f: 'Float' },
          'Bytes.Encode.Encoder',
        ) { |e, f|
          fmt = e.is_a?(Jade::Bytes::LE) ? 'E' : 'G'
          Jade::Bytes::Encode::Encoder[[f].pack(fmt)]
        }

        function(
          'string',
          { s: 'String' },
          'Bytes.Encode.Encoder',
        ) { |s| Jade::Bytes::Encode::Encoder[s.b] }

        function(
          'bytes',
          { b: 'Bytes.Bytes' },
          'Bytes.Encode.Encoder',
        ) { |b| Jade::Bytes::Encode::Encoder[b.bin] }

        function(
          'sequence',
          { encoders: 'List(Bytes.Encode.Encoder)' },
          'Bytes.Encode.Encoder',
        ) { |encoders| Jade::Bytes::Encode::Encoder[encoders.map(&:bin).join] }
      end
    end
  end
end
